import SwiftUI

struct SnippetsView: View {
    @ObservedObject var store = SnippetStore.shared
    @AppStorage("selectedSection") private var selectedSectionIndex: Int = 0
    @AppStorage("fontSize") private var fontSize: Double = 13
    @AppStorage("titleOnly") private var titleOnly: Bool = false
    var onPaste: ((String) -> Void)?
    var onClose: (() -> Void)?

    private var currentSnippets: [Snippet] {
        guard selectedSectionIndex < store.sections.count else { return [] }
        return store.sections[selectedSectionIndex].snippets
    }

    var body: some View {
        ZStack {
            VisualEffectBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                snippetsList
                Divider().background(Color.white.opacity(0.1))
                sectionTabs
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: store.sections.count) { _ in
            if selectedSectionIndex >= store.sections.count {
                selectedSectionIndex = max(0, store.sections.count - 1)
            }
        }
    }

    private var snippetsList: some View {
        ScrollView {
            VStack(spacing: 2) {
                if store.sections.isEmpty {
                    emptyState("Нет разделов.\nДобавьте их в Настройках.")
                } else if currentSnippets.isEmpty {
                    emptyState("Нет сниппетов в этом разделе.\nДобавьте их в Настройках.")
                } else {
                    ForEach(Array(currentSnippets.enumerated()), id: \.element.id) { index, snippet in
                        SnippetRow(
                            index: index,
                            snippet: snippet,
                            fontSize: fontSize,
                            titleOnly: titleOnly
                        ) {
                            onPaste?(snippet.content)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 50)
            .font(.system(size: fontSize))
    }

    private var sectionTabs: some View {
        let tagFont = max(9.0, fontSize - 2)
        let tabHeight = tagFont + 20
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                    TagButton(
                        title: section.name,
                        color: tagColor(for: index),
                        isSelected: selectedSectionIndex == index,
                        fontSize: tagFont
                    ) {
                        selectedSectionIndex = index
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(height: tabHeight)
    }

    private func tagColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .yellow, .cyan, .red]
        return colors[index % colors.count]
    }
}

struct TagButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    var fontSize: Double = 11
    let action: () -> Void

    var body: some View {
        let dotSize = max(5.0, fontSize * 0.6)
        Button(action: action) {
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: dotSize, height: dotSize)
                Text(title)
                    .font(.system(size: fontSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, fontSize * 0.65)
            .padding(.vertical, fontSize * 0.3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SnippetRow: View {
    let index: Int
    let snippet: Snippet
    let fontSize: Double
    let titleOnly: Bool
    let action: () -> Void
    @State private var hovered = false

    private var indexLabel: String {
        if index < 9 { return "\(index + 1)" }
        if index == 9 { return "0" }
        return ""
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(indexLabel)
                    .font(.system(size: fontSize - 1, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 16, alignment: .trailing)

                if titleOnly {
                    Text(snippet.title)
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(snippet.title)
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(snippet.content)
                            .font(.system(size: fontSize - 2))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, titleOnly ? 6 : 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovered ? Color.accentColor.opacity(0.25) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        v.material = .hudWindow
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
