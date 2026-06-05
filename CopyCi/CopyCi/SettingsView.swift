import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store = SnippetStore.shared
    @AppStorage("fontSize") private var fontSize: Double = 13
    @AppStorage("titleOnly") private var titleOnly: Bool = false
    @State private var autoLaunch: Bool = false
    @State private var recordingHotkey = false
    @State private var hotkeyDisplay = HotkeyManager.hotkeyDisplayString()
    @State private var newSectionName = ""
    @State private var expandedSections: Set<UUID> = []

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
                    appearanceSection
                    Divider()
                    snippetsSection
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 580)
        .onAppear { autoLaunch = isAutoLaunchEnabled() }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("General", systemImage: "gear").font(.headline)

            Toggle("Launch at Login", isOn: $autoLaunch)
                .onChange(of: autoLaunch) { setAutoLaunch($0) }

            HStack {
                Text("Hotkey")
                Spacer()
                Button(recordingHotkey ? "Press keys…" : hotkeyDisplay) {
                    recordingHotkey = true
                }
                .buttonStyle(.bordered)
                .background(hotkeyRecorderSetup)
            }
        }
    }

    // Invisible view that sets up the key monitor once
    private var hotkeyRecorderSetup: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
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
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Appearance", systemImage: "textformat.size").font(.headline)

            HStack {
                Text("Font size")
                Spacer()
                Text("\(Int(fontSize)) pt").foregroundColor(.secondary).frame(width: 40, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Text("A").font(.system(size: 10)).foregroundColor(.secondary)
                Slider(value: $fontSize, in: 10...18, step: 1)
                Text("A").font(.system(size: 18)).foregroundColor(.secondary)
            }
            Text("Preview: Hello, World!")
                .font(.system(size: fontSize))
                .foregroundColor(.secondary)

            Toggle("Show title only (hide content preview)", isOn: $titleOnly)
        }
    }

    // MARK: - Snippets

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Snippets", systemImage: "doc.text").font(.headline)

            Text("Drag sections and snippets to reorder")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach($store.sections) { $section in
                    SectionEditor(
                        section: $section,
                        isExpanded: expandedSections.contains(section.id)
                    ) {
                        if expandedSections.contains(section.id) {
                            expandedSections.remove(section.id)
                        } else {
                            expandedSections.insert(section.id)
                        }
                    } onDelete: {
                        store.sections.removeAll { $0.id == section.id }
                    }
                }
                .onMove { from, to in
                    store.sections.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 100, maxHeight: 400)
            .cornerRadius(8)

            HStack {
                TextField("New section name", text: $newSectionName)
                    .textFieldStyle(.roundedBorder)
                Button("Add Section") {
                    let name = newSectionName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.sections.append(SnippetSection(name: name, snippets: []))
                    newSectionName = ""
                }
                .buttonStyle(.bordered)
                .disabled(newSectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func isAutoLaunchEnabled() -> Bool {
        if #available(macOS 13, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    private func setAutoLaunch(_ enabled: Bool) {
        if #available(macOS 13, *) {
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}

// MARK: - SectionEditor

struct SectionEditor: View {
    @Binding var section: SnippetSection
    var isExpanded: Bool
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var newTitle = ""
    @State private var newContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                TextField("Section name", text: $section.name)
                    .font(.system(size: 13, weight: .semibold))
                    .textFieldStyle(.plain)

                Spacer()
                Text("\(section.snippets.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)

                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.secondary).font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if section.snippets.isEmpty {
                        Text("No snippets yet").font(.caption).foregroundColor(.secondary).padding(.leading, 20)
                    } else {
                        ForEach($section.snippets) { $snippet in
                            SnippetEditor(snippet: $snippet) {
                                section.snippets.removeAll { $0.id == snippet.id }
                            }
                        }
                        .onMove { from, to in
                            section.snippets.move(fromOffsets: from, toOffset: to)
                        }
                    }

                    // Add new snippet row
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        TextField("Title", text: $newTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        TextField("Content", text: $newContent)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let t = newTitle.trimmingCharacters(in: .whitespaces)
                            let c = newContent.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty, !c.isEmpty else { return }
                            section.snippets.append(Snippet(title: t, content: c))
                            newTitle = ""
                            newContent = ""
                        }
                        .buttonStyle(.bordered)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  newContent.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 4)
                }
                .padding(.bottom, 6)
            }
        }
    }
}

struct SnippetEditor: View {
    @Binding var snippet: Snippet
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            TextField("Title", text: $snippet.title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            TextField("Content", text: $snippet.content)
                .textFieldStyle(.roundedBorder)
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill").foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 20)
    }
}

private extension NSEvent.ModifierFlags {
    var carbonFlags: Int {
        var r = 0
        if contains(.command) { r |= cmdKey }
        if contains(.option)  { r |= optionKey }
        if contains(.control) { r |= controlKey }
        if contains(.shift)   { r |= shiftKey }
        return r
    }
}
