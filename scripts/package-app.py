#!/usr/bin/env python3
"""Build a standalone Apple Silicon app and ZIP; optionally sign and notarize."""
import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    return subprocess.run(args, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", help="Developer ID Application signing identity")
    parser.add_argument("--notary-profile", help="Existing notarytool Keychain profile; submits to Apple")
    parser.add_argument("--bundle-id", default="com.alperen.helios")
    parser.add_argument("--build-number", default="1")
    args = parser.parse_args()
    if args.notary_profile and not args.identity:
        parser.error("--notary-profile requires --identity")
    version = (ROOT / "Sources/Helios/Resources/VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        parser.error("VERSION must contain MAJOR.MINOR.PATCH")
    run("swift", "build", "-c", "release", "--arch", "arm64",
        "-Xswiftc", "-DHELIOS_DISTRIBUTION")
    binary_dir = Path(subprocess.check_output(
        ["swift", "build", "-c", "release", "--arch", "arm64", "--show-bin-path"], cwd=ROOT, text=True
    ).strip())
    destination = ROOT / "dist"
    destination.mkdir(exist_ok=True)
    # Stage a fresh bundle so old resources cannot leak into a new release.
    with tempfile.TemporaryDirectory(prefix="helios-package-") as staging:
        app = Path(staging) / "Helios.app"
        contents = app / "Contents"
        (contents / "MacOS").mkdir(parents=True)
        (contents / "Resources").mkdir()
        shutil.copy2(binary_dir / "Helios", contents / "MacOS/Helios")
        shutil.copyfile(ROOT / "LICENSE", contents / "Resources/LICENSE")
        shutil.copyfile(ROOT / "Assets/Helios.icns", contents / "Resources/Helios.icns")
        # The packaged app reads its version from Info.plist. No SwiftPM build
        # resources, debug files, or files from the working tree are shipped.
        run("strip", "-S", str(contents / "MacOS/Helios"))
        executable = (contents / "MacOS/Helios").read_bytes()
        if str(Path.home()).encode() in executable or str(ROOT).encode() in executable:
            raise RuntimeError("Release executable contains a local user/build path")
        info = {
            "CFBundleName": "Helios",
            "CFBundleDisplayName": "Helios",
            "CFBundleIdentifier": args.bundle_id,
            "CFBundleExecutable": "Helios",
            "CFBundleIconFile": "Helios.icns",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": args.build_number,
            "LSMinimumSystemVersion": "13.0",
            "LSUIElement": True,
            "NSHighResolutionCapable": True,
        }
        with (contents / "Info.plist").open("wb") as file:
            plistlib.dump(info, file)
        if args.identity:
            run("codesign", "--force", "--options", "runtime", "--timestamp", "--sign", args.identity, str(app))
        else:
            run("codesign", "--force", "--sign", "-", str(app))
        run("codesign", "--verify", "--strict", "--verbose=2", str(app))
        if args.notary_profile:
            upload = Path(staging) / "Helios-notarization.zip"
            run("ditto", "-c", "-k", "--norsrc", "--noextattr", "--keepParent", str(app), str(upload))
            run("xcrun", "notarytool", "submit", str(upload), "--keychain-profile", args.notary_profile, "--wait")
            run("xcrun", "stapler", "staple", str(app))
            run("xcrun", "stapler", "validate", str(app))
            run("spctl", "--assess", "--type", "execute", "--verbose=2", str(app))
        output_app = destination / "Helios.app"
        if output_app.exists():
            shutil.rmtree(output_app)
        shutil.copytree(app, output_app, symlinks=True)
        archive = destination / f"Helios-{version}-arm64.zip"
        archive.unlink(missing_ok=True)
        run("ditto", "-c", "-k", "--norsrc", "--noextattr", "--keepParent", str(output_app), str(archive))
        # Check the actual downloadable artifact, not only the staging bundle.
        extracted = Path(staging) / "archive-check"
        run("ditto", "-x", "-k", str(archive), str(extracted))
        extracted_app = extracted / "Helios.app"
        run("codesign", "--verify", "--strict", "--verbose=2", str(extracted_app))
        if args.notary_profile:
            run("xcrun", "stapler", "validate", str(extracted_app))
            run("spctl", "--assess", "--type", "execute", "--verbose=2", str(extracted_app))
        print(f"App: {output_app}\nArchive: {archive}")
        if not args.notary_profile:
            print("Local build only: notarization has not been performed.")


if __name__ == "__main__":
    main()
