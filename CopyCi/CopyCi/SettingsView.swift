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
            toolbar
            Divider()
            content
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 560)
    }

    // MARK: Toolbar (Little Snitch style)

    private var toolbar: some View {
        HStack(spacing: 2) {
            Spacer()
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 19, weight: .regular))
                            .frame(height: 22)
                        Text(t.rawValue)
                            .font(.system(size: 10.5))
                    }
                    .foregroundColor(tab == t ? .primary : .secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tab == t
                                  ? Color(NSColor.selectedContentBackgroundColor).opacity(0.25)
                                  : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general:    GeneralTab()
        case .appearance: AppearanceTab()
        case .snippets:   SnippetsTab()
        }
    }
}

// MARK: - Общий компонент формы

struct FormBlock<Content: View>: View {
    var title: String? = nil
    var note: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                    .padding(.leading, 2)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                    .padding(.leading, 2)
            }
        }
    }
}

struct FormRow<Label: View, Control: View>: View {
    var showDivider: Bool = true
    @ViewBuilder let label: () -> Label
    @ViewBuilder let control: () -> Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                label()
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                control()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            if showDivider {
                Divider().padding(.leading, 14)
            }
        }
    }
}

// MARK: - Основные

struct GeneralTab: View {
    @State private var autoLaunch = false
    @State private var recordingHotkey = false
    @State private var hotkeyDisplay = HotkeyManager.hotkeyDisplayString()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FormBlock(title: "Запуск") {
                    FormRow(showDivider: false) {
                        Text("Автозапуск при входе в систему")
                    } control: {
                        Toggle("", isOn: $autoLaunch).labelsHidden()
                            .onChange(of: autoLaunch, perform: setAutoLaunch)
                    }
                }

                FormBlock(title: "Горячая клавиша",
                          note: "Используется для показа/скрытия окна сниппетов.") {
                    FormRow(showDivider: false) {
                        Text(recordingHotkey ? "Нажмите сочетание клавиш…" : "Показать окно")
                            .foregroundColor(recordingHotkey ? .secondary : .primary)
                    } control: {
                        Button(recordingHotkey ? "Отмена" : hotkeyDisplay) {
                            recordingHotkey.toggle()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(recordingHotkey ? .orange : .accentColor)
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 320)
        .onAppear {
            autoLaunch = isAutoLaunchEnabled()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard self.recordingHotkey else { return event }
                let mods = event.modifierFlags.carbonFlags
                guard mods != 0 else { return event } // require modifier
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
    private func setAutoLaunch(_ v: Bool) {
        if #available(macOS 13, *) { try? v ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
    }
}

// MARK: - Внешний вид

struct AppearanceTab: View {
    @AppStorage("fontSize") private var fontSize: Double = 13
    @AppStorage("titleOnly") private var titleOnly: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FormBlock(title: "Шрифт") {
                    FormRow {
                        Text("Размер текста")
                    } control: {
                        HStack(spacing: 8) {
                            Text("А").font(.system(size: 11)).foregroundColor(.secondary)
                            Slider(value: $fontSize, in: 10...18, step: 1).frame(width: 130)
                            Text("А").font(.system(size: 16)).foregroundColor(.secondary)
                            Text("\(Int(fontSize)) пт")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 36)
                        }
                    }
                    FormRow(showDivider: false) {
                        Text("Предпросмотр")
                    } control: {
                        Text("Пример сниппета")
                            .font(.system(size: fontSize))
                            .foregroundColor(.secondary)
                    }
                }

                FormBlock(title: "Список сниппетов") {
                    FormRow(showDivider: false) {
                        Text("Показывать только название")
                    } control: {
                        Toggle("", isOn: $titleOnly).labelsHidden()
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 320)
    }
}

// MARK: - Сниппеты

struct SnippetsTab: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var selectedSectionID: UUID?
    @State private var selectedSnippetID: UUID?

    private var sectionIdx: Int? {
        store.sections.firstIndex { $0.id == selectedSectionID }
    }
    private var snippetIdx: Int? {
        guard let si = sectionIdx, let id = selectedSnippetID else { return nil }
        return store.sections[si].snippets.firstIndex { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            sectionsCol
            Divider()
            if sectionIdx != nil {
                snippetsCol
                Divider()
                editorCol
            } else {
                emptyCol(icon: "folder", text: "Выберите раздел")
            }
        }
        .frame(height: 360)
    }

    // MARK: Column 1 — sections

    private var sectionsCol: some View {
        VStack(spacing: 0) {
            colHeader("Разделы")
            List(selection: $selectedSectionID) {
                ForEach($store.sections) { $s in
                    SectionRow(section: $s, isSelected: selectedSectionID == s.id)
                        .tag(s.id)
                }
                .onMove { store.sections.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { idx in
                    if store.sections[idx.first!].id == selectedSectionID {
                        selectedSectionID = nil; selectedSnippetID = nil
                    }
                    store.sections.remove(atOffsets: idx)
                }
            }
            .listStyle(.sidebar)
            listToolbar(
                onAdd: {
                    let s = SnippetSection(name: "Новый раздел", snippets: [])
                    store.sections.append(s)
                    selectedSectionID = s.id
                    selectedSnippetID = nil
                },
                onRemove: selectedSectionID == nil ? nil : {
                    guard let id = selectedSectionID,
                          let i = store.sections.firstIndex(where: { $0.id == id }) else { return }
                    store.sections.remove(at: i)
                    selectedSectionID = nil; selectedSnippetID = nil
                }
            )
        }
        .frame(width: 160)
    }

    // MARK: Column 2 — snippets list

    private var snippetsCol: some View {
        VStack(spacing: 0) {
            if let si = sectionIdx {
                colHeader(store.sections[si].name)
                List(selection: $selectedSnippetID) {
                    ForEach(store.sections[si].snippets) { snippet in
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
                        .padding(.vertical, 1)
                    }
                    .onMove { store.sections[si].snippets.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { idx in
                        if store.sections[si].snippets[idx.first!].id == selectedSnippetID {
                            selectedSnippetID = nil
                        }
                        store.sections[si].snippets.remove(atOffsets: idx)
                    }
                }
                .listStyle(.plain)
                listToolbar(
                    onAdd: {
                        let s = Snippet(title: "Новый сниппет", content: "")
                        store.sections[si].snippets.append(s)
                        selectedSnippetID = s.id
                    },
                    onRemove: selectedSnippetID == nil ? nil : {
                        guard let id = selectedSnippetID else { return }
                        store.sections[si].snippets.removeAll { $0.id == id }
                        selectedSnippetID = nil
                    }
                )
            }
        }
        .frame(width: 185)
    }

    // MARK: Column 3 — editor

    @ViewBuilder
    private var editorCol: some View {
        if let si = sectionIdx, let pi = snippetIdx {
            SnippetEditor(snippet: $store.sections[si].snippets[pi])
        } else {
            emptyCol(icon: "doc.text", text: "Выберите сниппет")
        }
    }

    // MARK: Shared

    private func colHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)
    }

    private func listToolbar(onAdd: @escaping () -> Void, onRemove: (() -> Void)?) -> some View {
        HStack(spacing: 0) {
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .frame(width: 26, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 16)

            Button {
                onRemove?()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 26, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(onRemove == nil)

            Spacer()
        }
        .padding(.leading, 4)
        .frame(height: 28)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }

    private func emptyCol(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Color(NSColor.quaternaryLabelColor))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor).opacity(0.3))
    }
}

struct SectionRow: View {
    @Binding var section: SnippetSection
    let isSelected: Bool
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            if editing {
                TextField("", text: $draft, onCommit: commit)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onExitCommand { editing = false }
            } else {
                Text(section.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .onTapGesture(count: 2) { startEditing() }
            }
        }
        .onChange(of: isSelected) { selected in
            if !selected && editing { commit() }
        }
    }

    private func startEditing() {
        draft = section.name
        editing = true
    }

    private func commit() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { section.name = name }
        editing = false
    }
}

struct SnippetEditor: View {
    @Binding var snippet: Snippet
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Название сниппета", text: $snippet.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .focused($titleFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            ZStack(alignment: .topLeading) {
                if snippet.content.isEmpty {
                    Text("Содержимое сниппета…")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(NSColor.placeholderTextColor))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $snippet.content)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))

            Divider()

            // Footer
            HStack {
                Text("\(snippet.content.count) симв.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Spacer()
                Text("\(snippet.content.components(separatedBy: .newlines).count) стр.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers

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
