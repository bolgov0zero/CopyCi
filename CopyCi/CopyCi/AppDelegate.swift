import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var snippetsPanel: SnippetsPanel?
    private var settingsWindow: NSWindow?
    private var globalClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupHotkey()
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyCi")
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusBarClicked)
            button.target = self
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleSnippetsWindow(near: mousePosition())
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit CopyCi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "CopyCi Settings"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Snippets panel

    private func setupHotkey() {
        HotkeyManager.shared.onActivate = { [weak self] in
            self?.toggleSnippetsWindow(near: self?.mousePosition() ?? .zero)
        }
        HotkeyManager.shared.register()
    }

    func toggleSnippetsWindow(near point: NSPoint) {
        if let panel = snippetsPanel, panel.isVisible {
            hideSnippetsPanel()
            return
        }
        showSnippetsWindow(near: point)
    }

    private func showSnippetsWindow(near point: NSPoint) {
        if snippetsPanel == nil {
            snippetsPanel = SnippetsPanel(onClose: { [weak self] in
                self?.hideSnippetsPanel()
            })
        }
        snippetsPanel?.showNear(point: point)
        startClickOutsideMonitor()
    }

    func hideSnippetsPanel() {
        snippetsPanel?.orderOut(nil)
        stopClickOutsideMonitor()
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hideSnippetsPanel()
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    private func mousePosition() -> NSPoint { NSEvent.mouseLocation }
}

// MARK: - SnippetsPanel

class SnippetsPanel: NSPanel {
    private var localKeyMonitor: Any?
    var onClose: (() -> Void)?

    init(onClose: @escaping () -> Void) {
        // Restore saved size or use default
        let savedSize = SnippetsPanel.savedSize()
        let rect = NSRect(origin: .zero, size: savedSize)

        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable, .borderless],
            backing: .buffered,
            defer: false
        )

        self.onClose = onClose
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        minSize = NSSize(width: 260, height: 200)

        let view = SnippetsView(onPaste: { [weak self] in
            self?.onClose?()
        })
        contentView = NSHostingView(rootView: view)
    }

    func showNear(point: NSPoint) {
        let size = frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main!
        let sf = screen.visibleFrame

        var origin = NSPoint(x: point.x + 10, y: point.y - size.height - 10)
        if origin.x + size.width > sf.maxX { origin.x = point.x - size.width - 10 }
        if origin.y < sf.minY { origin.y = point.y + 20 }
        if origin.x < sf.minX { origin.x = sf.minX + 8 }

        setFrameOrigin(origin)
        orderFrontRegardless()
        startKeyMonitor()
    }

    override func orderOut(_ sender: Any?) {
        stopKeyMonitor()
        saveSize()
        super.orderOut(sender)
    }

    // MARK: Key monitor (Esc + number shortcuts)

    private func startKeyMonitor() {
        stopKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }

            // Esc → close
            if event.keyCode == 53 {
                self.onClose?()
                return nil
            }

            // 1–9, 0 → quick paste
            let numberKeys: [UInt16: Int] = [
                18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
                22: 5, 26: 6, 28: 7, 25: 8, 29: 9
            ]
            if let idx = numberKeys[event.keyCode], event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                let store = SnippetStore.shared
                let selectedSection = UserDefaults.standard.integer(forKey: "selectedSection")
                guard selectedSection < store.sections.count else { return nil }
                let snippets = store.sections[selectedSection].snippets
                let snippetIndex = idx == 0 ? 9 : idx - 1
                if snippetIndex < snippets.count {
                    let content = snippets[snippetIndex].content
                    self.onClose?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        PasteManager.paste(content)
                    }
                }
                return nil
            }

            return event
        }
    }

    private func stopKeyMonitor() {
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
    }

    // MARK: Size persistence

    private func saveSize() {
        let s = frame.size
        UserDefaults.standard.set(["w": s.width, "h": s.height], forKey: "snippetsPanelSize")
    }

    static func savedSize() -> NSSize {
        if let d = UserDefaults.standard.dictionary(forKey: "snippetsPanelSize"),
           let w = d["w"] as? CGFloat, let h = d["h"] as? CGFloat, w > 0, h > 0 {
            return NSSize(width: w, height: h)
        }
        return NSSize(width: 320, height: 400)
    }
}
