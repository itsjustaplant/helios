import AppKit
import Carbon
import ServiceManagement

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class Switcher: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var panel: NSPanel?
    private var monitor: Any?
    private var timer: Timer?
    private var inactivityTimer: Timer?
    private var selected = 0
    private var current: Int?
    private var rows: [InputRow] = []
    private var statusItem: NSStatusItem?
    private var delayItems: [NSMenuItem] = []
    private var loginItem: NSMenuItem?
    private var loginApprovalItem: NSMenuItem?
    private var isAppBundle: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    private var switchDelay: Int = {
        let stored = UserDefaults.standard.object(forKey: "switchDelay") as? Int ?? 5
        return [0, 5, 10].contains(stored) ? stored : 5
    }()
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menuIcon = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Helios input switcher")
        menuIcon?.isTemplate = true
        item.button?.image = menuIcon
        let menu = NSMenu()
        menu.delegate = self
        let show = NSMenuItem(title: "Show Helios", action: #selector(showSwitcher), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let delayHeading = NSMenuItem(title: "Switch Delay", action: nil, keyEquivalent: "")
        delayHeading.isEnabled = false
        menu.addItem(delayHeading)
        for (title, seconds) in [("Immediate", 0), ("5s", 5), ("10s", 10)] {
            let option = NSMenuItem(title: title, action: #selector(changeDelay(_:)), keyEquivalent: "")
            option.target = self
            option.tag = seconds
            option.state = seconds == switchDelay ? .on : .off
            menu.addItem(option)
            delayItems.append(option)
        }
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: isAppBundle ? #selector(toggleLaunchAtLogin) : nil, keyEquivalent: "")
        login.target = self
        login.toolTip = "Start Helios automatically when you log in to your Mac. Requires the installed app."
        menu.addItem(login)
        loginItem = login
        let approval = NSMenuItem(title: "Approve in System Settings…", action: #selector(openLoginSettings), keyEquivalent: "")
        approval.target = self
        menu.addItem(approval)
        loginApprovalItem = approval
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Helios", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.addItem(.separator())
        let versionItem = NSMenuItem(title: "Helios \(AppVersion.current)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        item.menu = menu
        statusItem = item
        configureLaunchAtLogin()
        print("Helios running. Press Control-Option-H to open the switcher; Control-C quits.")
    }

    @objc private func showSwitcher() { open() }

    private func configureLaunchAtLogin() {
        // Register once on the first bundled launch. Later changes in System
        // Settings belong to the user and must not be overridden on startup.
        if isAppBundle && !UserDefaults.standard.bool(forKey: "loginItemInitialized") {
            UserDefaults.standard.set(true, forKey: "loginItemInitialized")
            if SMAppService.mainApp.status == .notRegistered {
                do { try SMAppService.mainApp.register() }
                catch { fputs("Helios: Could not enable launch at login: \(error.localizedDescription)\n", stderr) }
            }
        }
        refreshLoginMenu()
    }

    func menuWillOpen(_ menu: NSMenu) { refreshLoginMenu() }

    private func refreshLoginMenu() {
        let status = isAppBundle ? SMAppService.mainApp.status : .notRegistered
        loginItem?.state = status == .enabled ? .on : (status == .requiresApproval ? .mixed : .off)
        loginApprovalItem?.isHidden = status != .requiresApproval
    }

    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    @objc private func toggleLaunchAtLogin() {
        guard isAppBundle else { return }
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: try SMAppService.mainApp.unregister()
            default: try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshLoginMenu()
    }

    @objc private func changeDelay(_ sender: NSMenuItem) {
        switchDelay = sender.tag
        UserDefaults.standard.set(switchDelay, forKey: "switchDelay")
        for item in delayItems { item.state = item.tag == switchDelay ? .on : .off }
    }

    private func switchInput(_ index: Int) {
        timer = nil
        do { _ = try command(["set-input", inputs[index].1]); close() }
        catch {
            render()
            status.stringValue = error.localizedDescription
        }
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
        let window = SwitcherPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 130), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.becomesKeyOnlyIfNeeded = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame { window.setFrameOrigin(NSPoint(x: frame.maxX - 336, y: frame.minY + 16)) }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 130))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.white.cgColor
        content.layer?.cornerRadius = 14
        content.layer?.borderWidth = 4
        content.layer?.borderColor = NSColor(srgbRed: 0.92, green: 0.92, blue: 0.93, alpha: 1).cgColor
        content.layer?.masksToBounds = true
        window.contentView = content
        rows = inputs.enumerated().map { index, input in
            let row = InputRow(frame: NSRect(x: 16, y: 70 - index * 54, width: 288, height: 44), title: "\(index + 1)   \(input.0)")
            row.onClick = { [weak self] in self?.choose(index) }
            content.addSubview(row)
            return row
        }
        status = NSTextField(wrappingLabelWithString: "")
        status.frame = NSRect(x: 18, y: 2, width: 284, height: 18)
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        content.addSubview(status)
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
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            switch event.keyCode {
            case 53: self.close()
            case 125: self.highlight((self.selected + 1) % self.inputs.count)
            case 126: self.highlight((self.selected + self.inputs.count - 1) % self.inputs.count)
            case 18: self.highlight(0)
            case 19: self.highlight(1)
            case 36, 76: self.choose(self.selected)
            default: return event
            }
            return nil
        }
    }

    private func render() {
        for i in inputs.indices { rows[i].stopProgress(); rows[i].update(selected: i == selected, current: i == current) }
    }
    private func highlight(_ index: Int) {
        guard current != nil else { return }
        timer?.invalidate(); timer = nil
        selected = index
        render()
        status.stringValue = ""
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }
    private func choose(_ index: Int) {
        guard current != nil else { return }
        inactivityTimer?.invalidate(); inactivityTimer = nil
        selected = index; timer?.invalidate(); render()
        status.stringValue = ""
        guard index != current else {
            inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            }
            return
        }
        guard switchDelay > 0 else { switchInput(index); return }
        rows[index].startProgress(duration: TimeInterval(switchDelay))
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(switchDelay), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.switchInput(index)
            }
        }
    }
    private func close() {
        inactivityTimer?.invalidate(); inactivityTimer = nil
        timer?.invalidate(); timer = nil
        rows.forEach { $0.stopProgress() }
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
