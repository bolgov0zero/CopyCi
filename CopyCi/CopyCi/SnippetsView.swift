import SwiftUI

struct SnippetsView: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var selectedSectionIndex: Int = 0
    @AppStorage("fontSize") private var fontSize: Double = 13
    var onPaste: (() -> Void)?

    private var currentSnippets: [Snippet] {
        guard selectedSectionIndex < store.sections.count else { return [] }
        return store.sections[selectedSectionIndex].snippets
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                snippetsList
                Divider()
                    .background(Color.white.opacity(0.1))
                sectionTabs
            }
        }
        .frame(width: 340, height: 400)
    }

    private var snippetsList: some View {
        ScrollView {
            VStack(spacing: 2) {
                if currentSnippets.isEmpty {
                    Text("No snippets.\nAdd them in Settings.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 50)
                        .font(.system(size: fontSize))
                } else {
                    ForEach(Array(currentSnippets.enumerated()), id: \.element.id) { index, snippet in
                        SnippetRow(
                            index: index,
                            snippet: snippet,
                            fontSize: fontSize,
                            onPaste: onPaste
                        )
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
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
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SnippetRow: View {
    let index: Int
    let snippet: Snippet
    let fontSize: Double
    var onPaste: (() -> Void)?
    @State private var hovered = false

    private var indexLabel: String {
        index < 9 ? "\(index + 1)" : "0"
    }

    var body: some View {
        Button(action: {
            onPaste?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                PasteManager.paste(snippet.content)
            }
        }) {
            HStack(spacing: 10) {
                Text(indexLabel)
                    .font(.system(size: fontSize - 1, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 16, alignment: .trailing)

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

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
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
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
