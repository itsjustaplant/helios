# Helios

Run from the project directory (builds the current source and starts Helios):

```sh
swift run Helios window
```

Or open an already installed copy:

```sh
open /Applications/Helios.app
```

Helios runs in the menu bar. Press Control–Option–H to open the input switcher.

Select a source with the arrow keys or number keys, then press Enter to start
switching. Press Enter during the countdown to finish the remaining time at 5×
speed. The progress bar speeds up too; further presses keep the same speed.

Helios is a lightweight macOS menu bar app for switching a supported external monitor between HDMI 1 and DisplayPort. Features include a Control–Option–H shortcut, keyboard and mouse controls, Return to confirm keyboard selections, immediate switching or a saved 3-, 5-, or 10-second delay, a visual countdown, automatic dismissal after inactivity, and optional launch at login (enabled by default). [Build and install it once](INSTALLATION.md) with `sh install.sh`, which downloads the latest source, installs the app, and opens it. To build your existing checkout, use `python3 scripts/install-app.py`; development runs can use `swift run Helios window`. Building requires an Apple Silicon Mac, Swift 6.2 or later, and Python 3; running requires macOS 13 or later and exactly one supported external monitor set as the main display.
