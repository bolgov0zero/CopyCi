import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var autoLaunch: Bool = false
    @State private var recordingHotkey = false
    @State private var hotkeyDisplay = HotkeyManager.hotkeyDisplayString()
    @State private var newSectionName = ""
    @State private var expandedSection: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2).bold()
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    generalSection
                    Divider()
                    snippetsSection
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 520)
        .onAppear { autoLaunch = isAutoLaunchEnabled() }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("General", systemImage: "gear")
                .font(.headline)

            Toggle("Launch at Login", isOn: $autoLaunch)
                .onChange(of: autoLaunch) { setAutoLaunch($0) }

            HStack {
                Text("Hotkey")
                Spacer()
                Button(recordingHotkey ? "Press keys…" : hotkeyDisplay) {
                    recordingHotkey = true
                }
                .buttonStyle(.bordered)
                .onAppear { setupHotkeyRecording() }
            }
        }
    }

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Snippets", systemImage: "doc.text")
                .font(.headline)

            ForEach($store.sections) { $section in
                SectionEditor(section: $section, isExpanded: expandedSection == section.id) {
                    expandedSection = expandedSection == section.id ? nil : section.id
                } onDelete: {
                    store.sections.removeAll { $0.id == section.id }
                }
            }

            HStack {
                TextField("New section name", text: $newSectionName)
                    .textFieldStyle(.roundedBorder)
                Button("Add Section") {
                    guard !newSectionName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.sections.append(SnippetSection(name: newSectionName, snippets: []))
                    newSectionName = ""
                }
                .buttonStyle(.bordered)
                .disabled(newSectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func setupHotkeyRecording() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.recordingHotkey else { return event }
            let mods = event.modifierFlags.carbonFlags
            let keyCode = Int(event.keyCode)
            HotkeyManager.saveHotkey(keyCode: keyCode, modifiers: UInt32(mods))
            self.hotkeyDisplay = HotkeyManager.hotkeyDisplayString()
            self.recordingHotkey = false
            HotkeyManager.shared.register()
            return nil
        }
    }

    private func isAutoLaunchEnabled() -> Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setAutoLaunch(_ enabled: Bool) {
        if #available(macOS 13, *) {
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}

struct SectionEditor: View {
    @Binding var section: SnippetSection
    var isExpanded: Bool
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var newTitle = ""
    @State private var newContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                TextField("Section name", text: $section.name)
                    .font(.system(size: 13, weight: .semibold))
                    .textFieldStyle(.plain)

                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach($section.snippets) { $snippet in
                        SnippetEditor(snippet: $snippet) {
                            section.snippets.removeAll { $0.id == snippet.id }
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        TextField("Title", text: $newTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        TextField("Content", text: $newContent)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            guard !newTitle.isEmpty, !newContent.isEmpty else { return }
                            section.snippets.append(Snippet(title: newTitle, content: newContent))
                            newTitle = ""
                            newContent = ""
                        }
                        .buttonStyle(.bordered)
                        .disabled(newTitle.isEmpty || newContent.isEmpty)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SnippetEditor: View {
    @Binding var snippet: Snippet
    var onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Title", text: $snippet.title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
            TextField("Content", text: $snippet.content)
                .textFieldStyle(.roundedBorder)
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

private extension NSEvent.ModifierFlags {
    var carbonFlags: Int {
        var result = 0
        if contains(.command) { result |= cmdKey }
        if contains(.option) { result |= optionKey }
        if contains(.control) { result |= controlKey }
        if contains(.shift) { result |= shiftKey }
        return result
    }
}
