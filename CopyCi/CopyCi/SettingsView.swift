import SwiftUI
import Carbon
import ServiceManagement

// MARK: - Root

struct SettingsView: View {
    @State private var tab: Tab = .general

    enum Tab: String, CaseIterable {
        case general    = "Основные"
        case appearance = "Внешний вид"
        case snippets   = "Сниппеты"

        var icon: String {
            switch self {
            case .general:    return "gearshape"
            case .appearance: return "paintbrush"
            case .snippets:   return "doc.text"
            }
        }
    }

    var body: some View {
        ZStack {
            // Full-window vibrancy — blends with desktop like Finder/System Settings
            SettingsVibrancy(material: .sidebar)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar area (sits under real titlebar)
                tabBar
                    .padding(.top, 44) // leave room for native titlebar

                Divider().opacity(0.3)

                // Content
                contentArea
            }
        }
        .frame(width: 580, height: 500)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { t in
                TabBarItem(tab: t, isSelected: tab == t) { tab = t }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch tab {
        case .general:    GeneralTab()
        case .appearance: AppearanceTab()
        case .snippets:   SnippetsTab()
        }
    }
}

struct TabBarItem: View {
    let tab: SettingsView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(width: 100, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.12)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Основные

struct GeneralTab: View {
    @State private var autoLaunch = false
    @State private var recordingHotkey = false
    @State private var hotkeyDisplay = HotkeyManager.hotkeyDisplayString()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroup(title: "Запуск") {
                    SettingsRow {
                        Toggle("Запускать при входе в систему", isOn: $autoLaunch)
                            .onChange(of: autoLaunch, perform: setAutoLaunch)
                    }
                }

                SettingsGroup(title: "Горячая клавиша") {
                    SettingsRow {
                        HStack {
                            Text("Сочетание клавиш")
                            Spacer()
                            Button(recordingHotkey ? "Нажмите клавиши…" : hotkeyDisplay) {
                                recordingHotkey = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(recordingHotkey ? .orange : .primary)
                        }
                    }
                    if recordingHotkey {
                        SettingsRow {
                            Text("Нажмите любое сочетание клавиш с модификатором (⌘, ⌥, ⌃, ⇧)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(.clear)
        .onAppear {
            autoLaunch = isAutoLaunchEnabled()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard self.recordingHotkey else { return event }
                let mods = event.modifierFlags.carbonFlags
                HotkeyManager.saveHotkey(keyCode: Int(event.keyCode), modifiers: UInt32(mods))
                self.hotkeyDisplay = HotkeyManager.hotkeyDisplayString()
                self.recordingHotkey = false
                HotkeyManager.shared.register()
                return nil
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

// MARK: - Внешний вид

struct AppearanceTab: View {
    @AppStorage("fontSize") private var fontSize: Double = 13
    @AppStorage("titleOnly") private var titleOnly: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroup(title: "Шрифт") {
                    SettingsRow {
                        HStack {
                            Text("Размер шрифта")
                            Spacer()
                            Text("\(Int(fontSize)) пт")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    SettingsRow {
                        HStack(spacing: 10) {
                            Text("А").font(.system(size: 10)).foregroundColor(.secondary)
                            Slider(value: $fontSize, in: 10...18, step: 1)
                            Text("А").font(.system(size: 18)).foregroundColor(.secondary)
                        }
                    }
                    SettingsRow {
                        Text("Пример текста сниппета")
                            .font(.system(size: fontSize))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                SettingsGroup(title: "Отображение") {
                    SettingsRow {
                        Toggle("Показывать только название (без превью содержимого)", isOn: $titleOnly)
                    }
                }
            }
            .padding(20)
        }
        .background(.clear)
    }
}

// MARK: - Сниппеты

struct SnippetsTab: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var selectedSectionID: UUID?
    @State private var selectedSnippetID: UUID?
    @State private var newSectionName = ""

    private var selectedSectionIndex: Int? {
        store.sections.firstIndex { $0.id == selectedSectionID }
    }

    var body: some View {
        HStack(spacing: 0) {
            sectionsColumn
            Divider().opacity(0.4)
            if let idx = selectedSectionIndex {
                SnippetsColumn(
                    section: $store.sections[idx],
                    selectedSnippetID: $selectedSnippetID
                )
            } else {
                centeredPlaceholder("Выберите раздел")
            }
        }
        .background(.clear)
    }

    private var sectionsColumn: some View {
        VStack(spacing: 0) {
            Text("Разделы")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().opacity(0.3)

            List(selection: $selectedSectionID) {
                ForEach(store.sections) { section in
                    Text(section.name)
                        .tag(section.id)
                        .lineLimit(1)
                }
                .onMove { from, to in store.sections.move(fromOffsets: from, toOffset: to) }
                .onDelete { store.sections.remove(atOffsets: $0) }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().opacity(0.3)

            HStack(spacing: 6) {
                TextField("Новый раздел", text: $newSectionName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addSection() }
                Button(action: addSection) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(newSectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
        }
        .frame(width: 165)
        .background(.ultraThinMaterial)
    }

    private func addSection() {
        let name = newSectionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let s = SnippetSection(name: name, snippets: [])
        store.sections.append(s)
        selectedSectionID = s.id
        newSectionName = ""
    }
}

struct SnippetsColumn: View {
    @Binding var section: SnippetSection
    @Binding var selectedSnippetID: UUID?

    private var selectedSnippetIndex: Int? {
        section.snippets.firstIndex { $0.id == selectedSnippetID }
    }

    var body: some View {
        HSplitView {
            snippetList
            if let idx = selectedSnippetIndex {
                SnippetEditorPanel(snippet: $section.snippets[idx])
                    .frame(minWidth: 190)
            } else {
                centeredPlaceholder("Выберите сниппет")
                    .frame(minWidth: 190)
            }
        }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            Text(section.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().opacity(0.3)

            List(selection: $selectedSnippetID) {
                ForEach(section.snippets) { snippet in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(snippet.content)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .tag(snippet.id)
                    .padding(.vertical, 2)
                }
                .onMove { from, to in section.snippets.move(fromOffsets: from, toOffset: to) }
                .onDelete { section.snippets.remove(atOffsets: $0) }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().opacity(0.3)

            HStack(spacing: 2) {
                Button {
                    let s = Snippet(title: "Новый сниппет", content: "")
                    section.snippets.append(s)
                    selectedSnippetID = s.id
                } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .padding(4)

                Button {
                    guard let id = selectedSnippetID else { return }
                    section.snippets.removeAll { $0.id == id }
                    selectedSnippetID = nil
                } label: { Image(systemName: "minus") }
                .buttonStyle(.borderless)
                .padding(4)
                .disabled(selectedSnippetID == nil)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(minWidth: 150)
    }
}

struct SnippetEditorPanel: View {
    @Binding var snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Название")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Название сниппета", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Содержимое")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $snippet.content)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(14)
    }
}

// MARK: - Reusable settings UI

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Divider().padding(.leading, 14), alignment: .bottom)
    }
}

// MARK: - NSVisualEffectView wrapper

struct SettingsVibrancy: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.material = material
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
    }
}

// MARK: - Helpers

private func centeredPlaceholder(_ text: String) -> some View {
    VStack {
        Spacer()
        Text(text).foregroundColor(.secondary)
        Spacer()
    }
    .frame(maxWidth: .infinity)
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
