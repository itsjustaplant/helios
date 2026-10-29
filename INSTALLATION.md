# Install Helios from source

Build once and keep Helios in your Applications folder. A paid Apple Developer
account is not needed to build for your own Mac. Local builds are ad hoc signed,
not Apple-notarized.

## Requirements

- An Apple Silicon Mac running macOS 13 or later.
- Swift 6.2 or later, provided by a compatible Xcode or Command Line Tools release.
- Git and Python 3 (`python3`).
- Exactly one external monitor set as the main display, with compatible DDC/CI
  support. Monitor and connection compatibility varies.

If developer tools are missing, run `xcode-select --install` and complete Apple's
installer. Check `swift --version` and `python3 --version` afterward. If the Swift
version is older than 6.2, install a newer compatible toolchain. The macOS version
needed to build may be newer than the version needed to run the resulting app.

## Install

```sh
(
  set -eu
  helios_source_dir="$(mktemp -d "${TMPDIR:-/tmp}/helios-install.XXXXXX")"
  trap 'rm -rf -- "$helios_source_dir"' EXIT
  git clone https://github.com/itsjustaplant/helios.git "$helios_source_dir/source"
  python3 "$helios_source_dir/source/scripts/install-app.py"
)
```

The script builds the release app and installs it at `~/Applications/Helios.app`
without administrator access. Open your home folder's Applications folder in
Finder and double-click Helios. Its sun icon appears in the menu bar; press
Control–Option–H to open the input switcher.

The commands clone and build in a temporary directory, then automatically delete
that directory, including the source and build output, when they finish or fail.
The installed app remains in `~/Applications` and is self-contained; opening it
does not rebuild it. Shared compiler caches may remain outside the temporary
directory. On its first installed launch, Helios enables Launch at Login. You
can turn this off in the menu. If macOS requires approval, use the menu's
"Approve in System Settings…" option. This starts Helios after you log in, not
before login.

To install into the system-wide Applications folder instead, if it is writable,
append `--app-dir /Applications` to the `python3` command in the block above.

Do not run the build with `sudo`. Local building does not grant Apple
notarization, and managed Macs may have additional launch restrictions.

## Update

Quit Helios from its menu, then repeat the installation commands. A verified new
bundle replaces the previous installation; the saved switch delay is retained.
There are no automatic updates. To build a specific published release, add
`--branch v1.0.0` to the `git clone` command once that tag exists and includes
the installer.

## Uninstall

Turn off Launch at Login, quit Helios, and move `~/Applications/Helios.app` to the Trash. If you installed
into `/Applications`, remove that copy instead.
