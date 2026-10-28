# Helios roadmap

Helios aims to switch a monitor's input from macOS, eventually through a floating window opened with a keyboard shortcut.

## 1. Validate the control path

- [x] Identify the monitor as a Dell U3415W and enable DDC/CI.
- [x] Read the current input over DDC/CI on the M4 Mac using m1ddc: HDMI 1 returned `17` (`0x11`).
- [x] Switch from HDMI 1 to DisplayPort using input value `15` (`0x0f`).
- [ ] Verify the return path to HDMI 1 and record any connection limitations.

## 2. Swift input-switching prototype

- [ ] Implement Helios’s own Apple Silicon DDC transport and input commands without a third-party DDC dependency.
- [ ] Account for the private macOS interfaces required for DDC and verify support for the current connection.
- [ ] Detect the connected monitor and identify it reliably.
- [ ] Read the current input and switch between the verified HDMI and DisplayPort inputs from a Swift command-line prototype.
- [ ] Report unsupported displays, communication failures, and unavailable inputs clearly.
- [ ] Validate switching on the actual monitor, including returning to the Mac input.

## 3. Floating window and shortcut

- [ ] Create a small floating window listing the available or configured inputs.
- [ ] Register a keyboard shortcut to show and dismiss it.
- [ ] Show the selected monitor and provide clear feedback when switching succeeds or fails.
- [ ] Validate the interaction on the actual setup.

## 4. Refine the experience

- [ ] Make input labels and the shortcut configurable.
- [ ] Handle display connection changes and multiple monitors.
- [ ] Document setup, compatibility, and recovery using the monitor's physical controls.
