import Foundation

struct Snippet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var content: String
}

struct SnippetSection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var snippets: [Snippet]
}

class SnippetStore: ObservableObject {
    static let shared = SnippetStore()

    @Published var sections: [SnippetSection] = [] {
        didSet { save() }
    }

    private let key = "snippetSections"

    init() {
        load()
        if sections.isEmpty {
            sections = [
                SnippetSection(name: "General", snippets: [
                    Snippet(title: "Hello", content: "Hello, World!"),
                    Snippet(title: "Email sign-off", content: "Best regards,\n")
                ])
            ]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SnippetSection].self, from: data)
        else { return }
        sections = decoded
    }
}
