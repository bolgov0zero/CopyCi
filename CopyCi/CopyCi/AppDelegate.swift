import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var snippetsPanel: SnippetsPanel?
    private var settingsWindow: NSWindow?
    private var previousApp: NSRunningApplication?
    private var clickOutsideMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupHotkey()
        // Request Accessibility on first launch so CGEvent paste works
        PasteManager.checkAccessibility()
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
            hideSnippetsPanel(restoreApp: true)
            return
        }
        showSnippetsWindow(near: point)
    }

    private func showSnippetsWindow(near point: NSPoint) {
        // Remember which app was active so we can restore it before paste
        previousApp = NSWorkspace.shared.frontmostApplication

        // Always start on first section
        UserDefaults.standard.set(0, forKey: "selectedSection")

        if snippetsPanel == nil {
            snippetsPanel = SnippetsPanel(onPaste: { [weak self] content in
                self?.pasteContent(content)
            }, onClose: { [weak self] in
                self?.hideSnippetsPanel(restoreApp: true)
            })
        }

        snippetsPanel?.showNear(point: point)
        NSApp.activate(ignoringOtherApps: true)
        snippetsPanel?.makeKeyAndOrderFront(nil)
        snippetsPanel?.startKeyMonitor()

        startClickOutsideMonitor()
    }

    func hideSnippetsPanel(restoreApp: Bool) {
        stopClickOutsideMonitor()
        snippetsPanel?.orderOut(nil)
        if restoreApp {
            previousApp?.activate(options: .activateIgnoringOtherApps)
        }
    }

    private func pasteContent(_ content: String) {
        hideSnippetsPanel(restoreApp: false)
        // Restore previous app first, then paste
        previousApp?.activate(options: .activateIgnoringOtherApps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            PasteManager.paste(content)
        }
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel = self.snippetsPanel, panel.isVisible else { return }
            // Check if click is outside panel frame (including resize handles)
            let mousePos = NSEvent.mouseLocation
            if !panel.frame.insetBy(dx: -10, dy: -10).contains(mousePos) {
                self.hideSnippetsPanel(restoreApp: true)
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
    }

    private func mousePosition() -> NSPoint { NSEvent.mouseLocation }
}

// MARK: - SnippetsPanel

class SnippetsPanel: NSPanel {
    var onPaste: ((String) -> Void)?
    var onClose: (() -> Void)?
    private var keyMonitor: Any?

    init(onPaste: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        let savedSize = SnippetsPanel.savedSize()

        super.init(
            contentRect: NSRect(origin: .zero, size: savedSize),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        self.onPaste = onPaste
        self.onClose = onClose

        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        minSize = NSSize(width: 240, height: 180)

        let view = SnippetsView(
            onPaste: { [weak self] content in self?.onPaste?(content) },
            onClose: { [weak self] in self?.onClose?() }
        )
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
    }

    // Called from AppDelegate AFTER makeKeyAndOrderFront
    func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Esc → close
            if event.keyCode == 53 {
                self.onClose?()
                return nil
            }

            // 1–9, 0 without modifiers → quick paste
            let numberMap: [UInt16: Int] = [
                18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
                22: 5, 26: 6, 28: 7, 25: 8, 29: 9
            ]
            if let pos = numberMap[event.keyCode],
               event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                let store = SnippetStore.shared
                let sectionIdx = UserDefaults.standard.integer(forKey: "selectedSection")
                guard sectionIdx < store.sections.count else { return nil }
                let snippets = store.sections[sectionIdx].snippets
                let snippetIdx = pos == 0 ? 9 : pos - 1
                guard snippetIdx < snippets.count else { return nil }
                self.onPaste?(snippets[snippetIdx].content)
                return nil
            }

            return event
        }
    }

    func stopKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func orderOut(_ sender: Any?) {
        stopKeyMonitor()
        saveSize()
        super.orderOut(sender)
    }

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
