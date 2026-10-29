#!/usr/bin/env python3
"""Build Helios once and install a standalone app in Applications."""
import argparse
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def install_app(source, app_dir):
    app_dir.mkdir(parents=True, exist_ok=True)
    destination = app_dir / "Helios.app"
    if destination.is_symlink():
        raise RuntimeError(f"Refusing to replace a symlink: {destination}")
    if destination.exists():
        try:
            info = plistlib.loads((destination / "Contents/Info.plist").read_bytes())
        except (OSError, plistlib.InvalidFileException) as error:
            raise RuntimeError(f"Existing destination is not a recognized Helios app: {destination}") from error
        if info.get("CFBundleIdentifier") != "com.alperen.helios":
            raise RuntimeError(f"Refusing to replace a different app: {destination}")
    # Copy and verify before moving the previous installation out of the way.
    # Stage on the destination volume so renames do not cross filesystems.
    with tempfile.TemporaryDirectory(prefix=".helios-install-", dir=app_dir) as staging:
        staged = Path(staging) / "Helios.app"
        backup = Path(staging) / "previous.app"
        shutil.copytree(source, staged)
        subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(staged)], check=True)
        had_previous = destination.exists()
        if had_previous:
            destination.rename(backup)
        try:
            staged.rename(destination)
        except OSError:
            if had_previous:
                backup.rename(destination)
            raise
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-dir", type=Path, default=Path("/Applications"),
                        help="Installation directory (default: /Applications)")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("Helios currently supports Apple Silicon Macs only.")
    if not shutil.which("swift"):
        parser.error("Install Xcode Command Line Tools with Swift 6.2 or later first.")
    result = subprocess.run(["swift", "--version"], check=True, text=True, capture_output=True)
    version = re.search(r"Swift version (\d+)\.(\d+)", result.stdout)
    if not version or tuple(map(int, version.groups())) < (6, 2):
        parser.error("Swift 6.2 or later is required. Update Xcode or Command Line Tools.")
    subprocess.run([sys.executable, str(ROOT / "scripts/package-app.py")], cwd=ROOT, check=True)
    try:
        destination = install_app(ROOT / "dist/Helios.app", args.app_dir.expanduser().resolve())
    except PermissionError:
        parser.exit(1, 'Cannot write to Applications. Install with --app-dir "$HOME/Applications" instead, or move dist/Helios.app there using Finder. Do not run the build with sudo.\n')
    print(f"Installed: {destination}")
    print("Open Helios.app from Finder. It runs from the menu bar.")
    print("The source folder is no longer needed to run it. Rebuild only when updating.")


if __name__ == "__main__":
    main()
