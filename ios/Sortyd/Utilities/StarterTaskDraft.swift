import Foundation

struct StarterTaskDraft: Identifiable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

extension Array where Element == StarterTaskDraft {
    mutating func updateDraftTitle(id: UUID, title: String) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        self[index].title = title
    }

    mutating func removeDraft(id: UUID) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        remove(at: index)
    }
}
