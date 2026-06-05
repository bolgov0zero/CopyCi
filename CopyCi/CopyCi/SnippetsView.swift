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
                    emptyState("No sections.\nAdd them in Settings.")
                } else if currentSnippets.isEmpty {
                    emptyState("No snippets in this section.\nAdd them in Settings.")
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                    TagButton(
                        title: section.name,
                        color: tagColor(for: index),
                        isSelected: selectedSectionIndex == index
                    ) {
                        selectedSectionIndex = index
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 38)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
