import Foundation

// MARK: - [2] Events list (spec/screens.md §2) — same behaviour as Android EventsViewModel

@MainActor
final class EventsViewModel: ObservableObject {
    @Published private(set) var events: [EventSummary] = []
    @Published private(set) var manuallyArchived: Set<String>
    @Published private(set) var loading = true
    /// Load error; cached cards stay visible (screens.md §2).
    @Published private(set) var error: AuthFailure?
    @Published var showArchive = false
    @Published var deleteTarget: EventSummary?
    @Published private(set) var deleting = false
    @Published var actionError: AuthFailure?
    @Published var deletedMessage = false
    @Published private(set) var now: Date

    private let repo: any EventRepository
    private let archive: any ArchiveStore
    private let clock: () -> Date

    init(repo: any EventRepository, archive: any ArchiveStore, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.archive = archive
        self.clock = clock
        manuallyArchived = archive.archived()
        now = clock()
    }

    func isArchived(_ e: EventSummary) -> Bool { manuallyArchived.contains(e.id) || EventRules.isArchivedByDate(e.startsAt, now: now) }

    /// Upcoming first (soonest on top), then events of the last 7 days (latest first).
    var active: [EventSummary] {
        let list = events.filter { !isArchived($0) }
        return list.filter { $0.startsAt >= now }.sorted { $0.startsAt < $1.startsAt } + list.filter { $0.startsAt < now }.sorted { $0.startsAt > $1.startsAt }
    }

    var archived: [EventSummary] { events.filter(isArchived).sorted { $0.startsAt > $1.startsAt } }

    /// Manual archiving can be undone; date-based archiving cannot.
    func canUnarchive(_ e: EventSummary) -> Bool { manuallyArchived.contains(e.id) && !EventRules.isArchivedByDate(e.startsAt, now: now) }

    func load() async {
        if events.isEmpty { loading = true }
        error = nil
        let result = await repo.list()
        now = clock()
        loading = false
        switch result {
        case let .success(list): events = list
        case let .failure(e): error = e
        }
    }

    func setArchived(_ e: EventSummary, _ value: Bool) {
        archive.setArchived(e.id, value)
        manuallyArchived = archive.archived()
    }

    func confirmDelete() async {
        guard let target = deleteTarget else { return }
        deleting = true
        let result = await repo.delete(target.id)
        deleting = false
        deleteTarget = nil
        switch result {
        case .success:
            archive.setArchived(target.id, false)
            manuallyArchived = archive.archived()
            events.removeAll { $0.id == target.id }
            deletedMessage = true
        case let .failure(e):
            actionError = e
        }
    }
}

// MARK: - [3] Create (6 steps)

/// What the map field shows under it (step 4).
enum MapStatus { case none, coordsFound, noCoords, invalid }

func mapStatus(_ link: String) -> MapStatus {
    switch MapsLink.parse(link) {
    case let .error(code): code == "empty" ? .none : .invalid
    case let .ok(lat, _): lat != nil ? .coordsFound : .noCoords
    }
}

@MainActor
final class CreateEventViewModel: ObservableObject {
    static let steps = 6

    @Published var draft: EventDraft { didSet { error = nil; now = clock() } }
    @Published private(set) var step = 1
    @Published private(set) var creating = false
    @Published private(set) var error: AuthFailure?
    @Published private(set) var createdId: String?
    @Published private(set) var now: Date

    private let repo: any EventRepository
    private let clock: () -> Date

    init(repo: any EventRepository, language: any AppLanguage, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.clock = clock
        draft = EventDraft(defaultLang: language.effective)
        now = clock()
    }

    var canNext: Bool { EventRules.stepValid(step, draft, now: now) && !creating }
    var isLast: Bool { step == Self.steps }

    func next() async {
        now = clock()
        guard canNext else { return }
        if !isLast { step += 1; return }
        creating = true; error = nil
        let result = await repo.create(draft)
        creating = false
        switch result {
        case let .success(id): createdId = id
        // The form stays as it was (screens.md §3).
        case let .failure(e): error = e
        }
    }

    func back() { if step > 1 { step -= 1 } }
}

// MARK: - [3] Edit — one page with sections

@MainActor
final class EditEventViewModel: ObservableObject {
    @Published private(set) var original: EventDraft?
    @Published var draft = EventDraft() { didSet { saved = false; error = nil; now = clock() } }
    @Published private(set) var loading = true
    @Published private(set) var saving = false
    @Published private(set) var error: AuthFailure?
    @Published private(set) var saved = false
    @Published private(set) var now: Date

    private let repo: any EventRepository
    private let eventId: String
    private let clock: () -> Date

    init(repo: any EventRepository, eventId: String, clock: @escaping () -> Date = Date.init) {
        self.repo = repo
        self.eventId = eventId
        self.clock = clock
        now = clock()
    }

    var changed: Bool { original.map { !EventRules.changes($0, draft).isEmpty } ?? false }
    /// A past date cannot be chosen (§15.4); an unchanged date of a past event does not block other edits.
    var dateOK: Bool { draft.startsAt == original?.startsAt || EventRules.dateOK(draft.startsAt, now: now) }
    var valid: Bool {
        draft.type != nil && EventRules.titleOK(draft.titleNames) && EventRules.hostsOK(draft.hostNames) && dateOK &&
            EventRules.venueOK(draft.venueName) && EventRules.mapsOK(draft.mapsURL)
    }
    var canSave: Bool { changed && valid && !saving }

    func load() async {
        loading = true; error = nil
        let result = await repo.get(eventId)
        loading = false
        switch result {
        case let .success(d):
            original = d
            draft = d
        case let .failure(e):
            error = e
        }
    }

    func save() async {
        now = clock()
        guard let original, canSave else { return }
        saving = true; error = nil
        let after = draft
        let result = await repo.update(eventId, before: original, after: after)
        saving = false
        switch result {
        // Last write wins when both families edit at once (screens.md §15.8).
        case .success:
            self.original = after
            saved = true
        case let .failure(e):
            error = e
        }
    }
}
