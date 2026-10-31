import Foundation

/// "Arxivlə" on screen [2] is a local view choice only (api.md §2 [2]: no server field in v1).
protocol ArchiveStore: AnyObject {
    func archived() -> Set<String>
    func setArchived(_ id: String, _ archived: Bool)
}

final class DefaultsArchiveStore: ArchiveStore {
    private let defaults: UserDefaults
    private let key = "events.archived_ids"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func archived() -> Set<String> { Set(defaults.stringArray(forKey: key) ?? []) }

    func setArchived(_ id: String, _ archived: Bool) {
        var ids = self.archived()
        if archived { ids.insert(id) } else { ids.remove(id) }
        defaults.set(Array(ids).sorted(), forKey: key)
    }
}
