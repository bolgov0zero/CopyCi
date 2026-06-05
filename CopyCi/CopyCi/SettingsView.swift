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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { t in
                    TabBarItem(tab: t, isSelected: tab == t) { tab = t }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().padding(.top, 8)

            Group {
                switch tab {
                case .general:    GeneralTab()
                case .appearance: AppearanceTab()
                case .snippets:   SnippetsTab()
                }
            }
        }
        .frame(width: 580, height: 500)
    }
}

struct TabBarItem: View {
    let tab: SettingsView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(tab.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(width: 96, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Основные

struct GeneralTab: View {
    @State private var autoLaunch = false
    @State private var recordingHotkey = false
    @State private var hotkeyDisplay = HotkeyManager.hotkeyDisplayString()

    var body: some View {
        Form {
            Section {
                Toggle("Запускать при входе в систему", isOn: $autoLaunch)
                    .onChange(of: autoLaunch, perform: setAutoLaunch)
            } header: {
                Text("Запуск")
            }

            Section {
                HStack {
                    Text("Сочетание клавиш")
                    Spacer()
                    Button(recordingHotkey ? "Нажмите клавиши…" : hotkeyDisplay) {
                        recordingHotkey = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(recordingHotkey ? .orange : .primary)
                }
            } header: {
                Text("Горячая клавиша")
            }
        }
        .formStyle(.grouped)
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
        Form {
            Section {
                HStack {
                    Text("Размер шрифта")
                    Spacer()
                    Text("\(Int(fontSize)) пт")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                HStack(spacing: 10) {
                    Text("А").font(.system(size: 10)).foregroundColor(.secondary)
                    Slider(value: $fontSize, in: 10...18, step: 1)
                    Text("А").font(.system(size: 18)).foregroundColor(.secondary)
                }
                Text("Пример текста сниппета")
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
            } header: {
                Text("Шрифт")
            }

            Section {
                Toggle("Показывать только название (без превью содержимого)", isOn: $titleOnly)
            } header: {
                Text("Отображение")
            }
        }
        .formStyle(.grouped)
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
            Divider()
            if let idx = selectedSectionIndex {
                SnippetsColumn(
                    section: $store.sections[idx],
                    selectedSnippetID: $selectedSnippetID
                )
            } else {
                placeholder("Выберите раздел")
            }
        }
    }

    private var sectionsColumn: some View {
        VStack(spacing: 0) {
            columnHeader("Разделы")

            List(selection: $selectedSectionID) {
                ForEach(store.sections) { section in
                    Text(section.name)
                        .tag(section.id)
                        .lineLimit(1)
                }
                .onMove { from, to in
                    store.sections.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { store.sections.remove(atOffsets: $0) }
            }
            .listStyle(.sidebar)

            Divider()

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
            .padding(8)
        }
        .frame(width: 160)
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
        VStack(spacing: 0) {
            columnHeader(section.name)

            HSplitView {
                snippetList
                if let idx = selectedSnippetIndex {
                    SnippetEditorPanel(snippet: $section.snippets[idx])
                        .frame(minWidth: 180)
                } else {
                    placeholder("Выберите сниппет")
                        .frame(minWidth: 180)
                }
            }
        }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
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
            .listStyle(.bordered)

            Divider()

            HStack(spacing: 4) {
                Button {
                    let s = Snippet(title: "Новый сниппет", content: "")
                    section.snippets.append(s)
                    selectedSnippetID = s.id
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    guard let id = selectedSnippetID else { return }
                    section.snippets.removeAll { $0.id == id }
                    selectedSnippetID = nil
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedSnippetID == nil)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 150)
    }
}

struct SnippetEditorPanel: View {
    @Binding var snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Название")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Название сниппета", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Содержимое")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $snippet.content)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            }
        }
        .padding(12)
    }
}

// MARK: - Shared helpers

private func columnHeader(_ title: String) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(NSColor.windowBackgroundColor))
    .overlay(Divider(), alignment: .bottom)
}

private func placeholder(_ text: String) -> some View {
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
