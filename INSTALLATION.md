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
curl -fsSLo /tmp/helios-install.sh https://raw.githubusercontent.com/itsjustaplant/helios/master/install.sh
sh /tmp/helios-install.sh
```

The script checks prerequisites, downloads the source, builds the release app,
installs it at `/Applications/Helios.app`, and opens it. You can inspect the
downloaded script before running it. If developer tools are missing, it opens
Apple's installer; complete that installation and run the script again. An older
Swift toolchain must be updated manually.

From an existing checkout, run `sh install.sh` to install the latest `master`
from GitHub, or `python3 scripts/install-app.py` to build that checkout instead.
Pass `--no-open` to the shell script to install without launching the app.

Its sun icon appears in the menu bar; press
Control–Option–H to open the input switcher.

The commands clone and build in a temporary directory, then automatically delete
that directory, including the source and build output, when they finish or fail.
The installed app remains in `/Applications` and is self-contained; opening it
does not rebuild it. Shared compiler caches may remain outside the temporary
directory. On its first installed launch, Helios enables Launch at Login. You
can turn this off in the menu. If macOS requires approval, use the menu's
"Approve in System Settings…" option. This starts Helios after you log in, not
before login.

If your account cannot write to `/Applications`, install into your user
Applications folder instead:

```sh
sh /tmp/helios-install.sh --app-dir "$HOME/Applications"
```

Do not run the build with `sudo`. Local building does not grant Apple
notarization, and managed Macs may have additional launch restrictions.

## Update

Quit Helios from its menu, then repeat the installation commands. A verified new
bundle replaces the previous installation; the saved switch delay is retained.
There are no automatic updates. To build a specific published release, run
`sh /tmp/helios-install.sh --ref v1.0.0` once that tag exists and includes the
installer.

## Uninstall

Turn off Launch at Login, quit Helios, and move `/Applications/Helios.app` to the
Trash. If you chose a different installation folder, remove that copy instead.
