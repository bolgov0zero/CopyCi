import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var snippetsWindow: NSPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupHotkey()
    }

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
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleSnippetsWindow(near: mousePosition())
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit CopyCi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
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

    private func setupHotkey() {
        HotkeyManager.shared.onActivate = { [weak self] in
            self?.toggleSnippetsWindow(near: self?.mousePosition() ?? .zero)
        }
        HotkeyManager.shared.register()
    }

    func toggleSnippetsWindow(near point: NSPoint) {
        if let window = snippetsWindow, window.isVisible {
            window.orderOut(nil)
            return
        }
        showSnippetsWindow(near: point)
    }

    private func showSnippetsWindow(near point: NSPoint) {
        if snippetsWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
                styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = ""
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear

            let view = SnippetsView(onPaste: { [weak panel] in
                panel?.orderOut(nil)
            })
            panel.contentView = NSHostingView(rootView: view)
            snippetsWindow = panel
        }

        positionWindow(snippetsWindow!, near: point)
        snippetsWindow?.orderFrontRegardless()
    }

    private func positionWindow(_ window: NSPanel, near point: NSPoint) {
        let size = window.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main!
        let screenFrame = screen.visibleFrame

        var origin = NSPoint(x: point.x + 10, y: point.y - size.height - 10)

        if origin.x + size.width > screenFrame.maxX {
            origin.x = point.x - size.width - 10
        }
        if origin.y < screenFrame.minY {
            origin.y = point.y + 20
        }

        window.setFrameOrigin(origin)
    }

    private func mousePosition() -> NSPoint {
        NSEvent.mouseLocation
    }
}
