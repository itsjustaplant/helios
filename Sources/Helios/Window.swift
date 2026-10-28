import AppKit
import Carbon

@MainActor
final class Switcher: NSObject, NSApplicationDelegate {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var panel: NSPanel?
    private var monitor: Any?
    private var timer: Timer?
    private var selected = 0
    private var current: Int?
    private var labels: [NSTextField] = []
    private var status = NSTextField(labelWithString: "")
    private let inputs = [("HDMI 1", "hdmi1", 17), ("DisplayPort", "displayport", 15)]

    func applicationDidFinishLaunching(_ notification: Notification) {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return noErr }
            let instance = Unmanaged<Switcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { instance.open() }
            return noErr
        }
        let installed = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let registered = RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x48454c49, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        if installed != noErr || registered != noErr {
            fputs("Helios: Could not register Control-Option-H.\n", stderr)
            NSApp.terminate(nil)
        }
        print("Helios running. Press Control-Option-H to open the switcher; Control-C quits.")
    }

    private func command(_ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard task.terminationStatus == 0 else { throw NSError(domain: "Helios", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output]) }
        return output
    }

    func open() {
        if panel?.isVisible == true { close(); return }
        timer?.invalidate()
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 180), styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        window.title = "Helios"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.becomesKeyOnlyIfNeeded = false
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame { window.setFrameOrigin(NSPoint(x: frame.maxX - 336, y: frame.minY + 16)) }
        let stack = NSStackView(frame: NSRect(x: 16, y: 16, width: 288, height: 140))
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.addArrangedSubview(NSTextField(labelWithString: "Select an input"))
        labels = inputs.map { _ in NSTextField(labelWithString: "") }
        labels.forEach { stack.addArrangedSubview($0) }
        status = NSTextField(wrappingLabelWithString: "↑ ↓ or 1–2 to select · Esc to cancel")
        stack.addArrangedSubview(status)
        window.contentView?.addSubview(stack)
        panel = window
        do {
            let result = try command(["read-input"])
            current = inputs.firstIndex { result.contains("input \($0.2) (") }
            selected = current ?? 0
            if current == nil { status.stringValue = "Current input is not in the list." }
        } catch {
            current = nil
            status.stringValue = error.localizedDescription
        }
        render()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            switch event.keyCode {
            case 53: self.close()
            case 125: self.choose((self.selected + 1) % 2)
            case 126: self.choose((self.selected + 1) % 2)
            case 18: self.choose(0)
            case 19: self.choose(1)
            default: return event
            }
            return nil
        }
    }
    private func render() {
        for i in inputs.indices {
            labels[i].stringValue = "\(i + 1). \(inputs[i].0)\(i == current ? "  • Current" : "")\(i == selected ? "  ◀" : "")"
        }
    }
    private func choose(_ index: Int) {
        guard current != nil else { return }
        selected = index; timer?.invalidate(); render()
        guard index != current else { status.stringValue = "Current input selected"; return }
        status.stringValue = "Switching in 1 second…"
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                do { _ = try self.command(["set-input", self.inputs[index].1]); self.close() }
                catch { self.status.stringValue = error.localizedDescription }
            }
        }
    }
    private func close() {
        timer?.invalidate(); timer = nil
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        panel?.orderOut(nil)
    }
}

@MainActor
func startWindow() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = Switcher()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
