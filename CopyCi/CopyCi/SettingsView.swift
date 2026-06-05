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
            case .general:    return "gearshape.fill"
            case .appearance: return "paintbrush.fill"
            case .snippets:   return "doc.text.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Native-style toolbar tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { t in
                    TabItem(tab: t, isSelected: tab == t) { withAnimation(.easeInOut(duration: 0.15)) { tab = t } }
                }
            }
            .frame(height: 56)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            Group {
                switch tab {
                case .general:    GeneralTab()
                case .appearance: AppearanceTab()
                case .snippets:   SnippetsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 480)
    }
}

struct TabItem: View {
    let tab: SettingsView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .frame(width: 100, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                    .padding(.horizontal, 4)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PrefSection(title: "Запуск") {
                    PrefRow("Автозапуск при входе в систему") {
                        Toggle("", isOn: $autoLaunch).labelsHidden()
                            .onChange(of: autoLaunch, perform: setAutoLaunch)
                    }
                }

                PrefSection(title: "Горячая клавиша") {
                    PrefRow("Показать окно сниппетов") {
                        Button(recordingHotkey ? "Нажмите клавиши…" : hotkeyDisplay) {
                            recordingHotkey = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(recordingHotkey ? .orange : .primary)
                        .animation(nil, value: recordingHotkey)
                    }
                }

                if recordingHotkey {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle").foregroundColor(.secondary)
                        Text("Нажмите сочетание клавиш с модификатором (⌘, ⌥, ⌃ или ⇧)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(24)
        }
        .onAppear {
            autoLaunch = isAutoLaunchEnabled()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard self.recordingHotkey else { return event }
                HotkeyManager.saveHotkey(keyCode: Int(event.keyCode),
                                         modifiers: UInt32(event.modifierFlags.carbonFlags))
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
            VStack(alignment: .leading, spacing: 24) {
                PrefSection(title: "Шрифт в окне сниппетов") {
                    PrefRow("Размер") {
                        HStack(spacing: 10) {
                            Text("А").font(.system(size: 11)).foregroundColor(.secondary)
                            Slider(value: $fontSize, in: 10...18, step: 1).frame(width: 160)
                            Text("А").font(.system(size: 17)).foregroundColor(.secondary)
                            Text("\(Int(fontSize)) пт")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .frame(width: 38, alignment: .leading)
                        }
                    }
                    Divider().padding(.leading, 16)
                    PrefRow("Предпросмотр") {
                        Text("Пример сниппета")
                            .font(.system(size: fontSize))
                            .foregroundColor(.secondary)
                    }
                }

                PrefSection(title: "Список сниппетов") {
                    PrefRow("Показывать только название") {
                        Toggle("", isOn: $titleOnly).labelsHidden()
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Сниппеты

struct SnippetsTab: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var selectedSectionID: UUID?
    @State private var selectedSnippetID: UUID?
    @State private var newSectionName = ""

    private var sectionIndex: Int? { store.sections.firstIndex { $0.id == selectedSectionID } }

    var body: some View {
        HStack(spacing: 0) {
            // Column 1 — sections
            VStack(spacing: 0) {
                List(selection: $selectedSectionID) {
                    ForEach(store.sections) { s in
                        Label(s.name, systemImage: "folder")
                            .tag(s.id)
                    }
                    .onMove { store.sections.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { store.sections.remove(atOffsets: $0) }
                }
                .listStyle(.sidebar)

                Divider()
                HStack(spacing: 0) {
                    ToolbarButton(icon: "plus") {
                        let s = SnippetSection(name: "Новый раздел", snippets: [])
                        store.sections.append(s)
                        selectedSectionID = s.id
                    }
                    ToolbarButton(icon: "minus") {
                        guard let id = selectedSectionID else { return }
                        store.sections.removeAll { $0.id == id }
                        selectedSectionID = nil
                    }
                    .disabled(selectedSectionID == nil)
                    Spacer()
                }
                .frame(height: 28)
            }
            .frame(width: 168)

            Divider()

            // Column 2 — snippets
            if let idx = sectionIndex {
                VStack(spacing: 0) {
                    // Editable section name
                    HStack {
                        Image(systemName: "folder").foregroundColor(.secondary).font(.caption)
                        TextField("Название раздела", text: $store.sections[idx].name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(store.sections[idx].snippets.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    List(selection: $selectedSnippetID) {
                        ForEach(store.sections[idx].snippets) { snippet in
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
                        .onMove { store.sections[idx].snippets.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { store.sections[idx].snippets.remove(atOffsets: $0) }
                    }
                    .listStyle(.plain)

                    Divider()
                    HStack(spacing: 0) {
                        ToolbarButton(icon: "plus") {
                            let s = Snippet(title: "Новый сниппет", content: "")
                            store.sections[idx].snippets.append(s)
                            selectedSnippetID = s.id
                        }
                        ToolbarButton(icon: "minus") {
                            guard let id = selectedSnippetID else { return }
                            store.sections[idx].snippets.removeAll { $0.id == id }
                            selectedSnippetID = nil
                        }
                        .disabled(selectedSnippetID == nil)
                        Spacer()
                    }
                    .frame(height: 28)
                }
                .frame(width: 200)

                Divider()

                // Column 3 — editor
                if let sID = selectedSnippetID,
                   let sIdx = store.sections[idx].snippets.firstIndex(where: { $0.id == sID }) {
                    SnippetEditorPanel(snippet: $store.sections[idx].snippets[sIdx])
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.secondary.opacity(0.4))
                        Text("Выберите сниппет").foregroundColor(.secondary).padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "folder").font(.system(size: 32)).foregroundColor(.secondary.opacity(0.4))
                    Text("Выберите раздел").foregroundColor(.secondary).padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct SnippetEditorPanel: View {
    @Binding var snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title field
            VStack(alignment: .leading, spacing: 4) {
                Label("Название", systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Название сниппета", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // Content editor
            VStack(alignment: .leading, spacing: 4) {
                Label("Содержимое", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 12)

                TextEditor(text: $snippet.content)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToolbarButton: View {
    let icon: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(isDisabled)
    }
}

// MARK: - Preference UI helpers

struct PrefSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 2)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5))
        }
    }
}

struct PrefRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: () -> Control

    init(_ label: String, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.control = control
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
