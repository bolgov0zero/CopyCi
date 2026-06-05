import SwiftUI

struct SnippetsView: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var selectedSectionIndex: Int = 0
    var onPaste: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            snippetsList
            Divider()
            sectionTabs
        }
        .frame(width: 320, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var snippetsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                if store.sections.isEmpty {
                    Text("No snippets yet.\nAdd them in Settings.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                } else if selectedSectionIndex < store.sections.count {
                    ForEach(store.sections[selectedSectionIndex].snippets) { snippet in
                        SnippetRow(snippet: snippet, onPaste: onPaste)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                    Button(action: { selectedSectionIndex = index }) {
                        Text(section.name)
                            .font(.system(size: 12, weight: selectedSectionIndex == index ? .semibold : .regular))
                            .foregroundColor(selectedSectionIndex == index ? .primary : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedSectionIndex == index
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 36)
    }
}

struct SnippetRow: View {
    let snippet: Snippet
    var onPaste: (() -> Void)?
    @State private var hovered = false

    var body: some View {
        Button(action: {
            onPaste?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                PasteManager.paste(snippet.content)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(snippet.content)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.secondary)
                    .opacity(hovered ? 1 : 0)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hovered ? Color.accentColor.opacity(0.08) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hovered = $0 }
    }
}
