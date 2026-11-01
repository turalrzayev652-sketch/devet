import Foundation

/// Filter chips of screen [6] (screens.md §6). Same as Android `GuestFilter`.
enum GuestFilter: CaseIterable, Identifiable {
    case all, groom, bride, coming, declined, noAnswer, unsent, noTable
    var id: Self { self }

    var labelKey: String {
        switch self {
        case .all: "guests.filter.all"
        case .groom: "guest.side.groom"
        case .bride: "guest.side.bride"
        case .coming: "guests.filter.coming"
        case .declined: "guests.filter.declined"
        case .noAnswer: "guests.filter.pending"
        case .unsent: "guests.filter.unsent"
        case .noTable: "guests.filter.no_table"
        }
    }

    func matches(_ g: Guest) -> Bool {
        switch self {
        case .all: true
        case .groom: g.side == .groom
        case .bride: g.side == .bride
        case .coming: g.status == .coming
        case .declined: g.status == .declined
        // Sent (seen or not) but not answered yet.
        case .noAnswer: g.status == .pending || g.status == .viewed
        case .unsent: g.status == .unsent
        case .noTable: (g.tableNo ?? "").trimmed.isEmpty
        }
    }
}

/// Search by name (case and Azerbaijani letters folded) or by phone digits (screens.md §6).
func searchMatches(_ g: Guest, _ query: String) -> Bool {
    let q = query.trimmed
    if q.isEmpty { return true }
    if ExcelRules.fold(g.name).contains(ExcelRules.fold(q)) { return true }
    // "050 123" must find +994 50 123…: the local trunk 0 is not part of E.164.
    let digits = String(q.filter(\.isNumber).drop { $0 == "0" })
    return digits.count >= 3 && (g.phoneE164?.filter(\.isNumber).contains(digits) ?? false)
}

/// Limit ring: ≥ 95 % gold with "N left", 100 % red with "limit reached" (screens.md §6).
enum LimitLevel { case normal, near, full }

func limitLevel(_ count: Int, _ limit: Int?) -> LimitLevel {
    guard let limit, limit > 0 else { return .normal }
    if count >= limit { return .full }
    if count * 100 >= limit * 95 { return .near }
    return .normal
}

/// Edit sheet (§6.1): the same form as manual add.
struct EditGuest: Identifiable {
    let guest: Guest
    var form: GuestForm
    var phoneProblem: PhoneIssue = .none
    var saving = false
    var attempted = false
    var id: String { guest.id }
    var nameError: Bool { attempted && !GuestRules.nameOK(form.name) }
    var canSave: Bool { GuestRules.nameOK(form.name) && phoneProblem == .none && GuestRules.tableOK(form.table) && !saving }
}

enum GuestMessage { case saved, deleted }

/// Screen [6] Guests (spec/screens.md §6, api.md §2 [6]). Owner may delete; a co-host may not (§13).
@MainActor
final class GuestListViewModel: ObservableObject {
    @Published private(set) var guests: [Guest] = []
    @Published private(set) var limit: Int?
    @Published private(set) var eventLang = "az"
    @Published private(set) var loading = true
    @Published private(set) var error: AuthFailure?
    @Published var query = ""
    @Published var filter: GuestFilter = .all
    @Published private(set) var selected: Set<String> = []
    @Published var editing: EditGuest?
    /// Ids waiting for the delete confirmation.
    @Published var confirmDelete: [String]?
    @Published var bulkTable = false
    @Published private(set) var busy = false
    @Published var actionError: AuthFailure?
    @Published var message: GuestMessage?

    let isOwner: Bool
    let spec: GuestSpec
    let eventId: String
    let repo: any GuestListRepository
    let events: any EventRepository

    init(eventId: String, isOwner: Bool, repo: any GuestListRepository, events: any EventRepository, spec: GuestSpec) {
        self.eventId = eventId
        self.isOwner = isOwner
        self.repo = repo
        self.events = events
        self.spec = spec
    }

    var visible: [Guest] { guests.filter { filter.matches($0) && searchMatches($0, query) } }
    func count(_ f: GuestFilter) -> Int { guests.filter(f.matches).count }
    var selecting: Bool { !selected.isEmpty }
    var level: LimitLevel { limitLevel(guests.count, limit) }

    func load() async {
        if guests.isEmpty { loading = true }
        error = nil
        if case let .success(d) = await events.get(eventId) { eventLang = d.defaultLang }
        let list = await repo.list(eventId)
        if case let .success(l) = await repo.limit(eventId), let l { limit = l }
        loading = false
        switch list {
        case let .success(g): guests = g
        // Cached rows stay visible (screens.md §6).
        case let .failure(e): error = e
        }
    }

    // MARK: selection (long press)

    func toggle(_ id: String) { if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } }
    func clearSelection() { selected = [] }

    // MARK: edit sheet

    func open(_ g: Guest) {
        editing = EditGuest(guest: g, form: GuestForm(salutation: g.salutation, name: g.name, withFamily: g.withFamily, count: g.invitedCount,
                                                       phone: g.phoneE164 ?? "", side: g.side, table: g.tableNo ?? "", lang: g.lang))
    }

    func edit(_ change: (inout GuestForm) -> Void) {
        guard var e = editing else { return }
        change(&e.form)
        e.form.name = String(e.form.name.prefix(GuestRules.maxName))
        e.form.table = String(e.form.table.prefix(GuestRules.maxTable))
        e.form.count = min(max(e.form.count, 1), GuestRules.maxCount)
        e.phoneProblem = phoneIssue(spec.phones, e.form.phone).1
        editing = e
    }

    func saveEdit() async {
        guard var e = editing else { return }
        guard e.canSave else { e.attempted = true; editing = e; return }
        let f = e.form
        let after = NewGuest(name: f.name.trimmed, salutation: f.salutation, withFamily: f.withFamily, invitedCount: f.count,
                             phoneE164: phoneIssue(spec.phones, f.phone).0, side: f.side, tableNo: f.table.trimmed.isEmpty ? nil : f.table.trimmed, lang: f.lang)
        e.saving = true; e.attempted = true; editing = e
        switch await repo.update(e.guest.id, before: e.guest.fields, after: after) {
        case .success:
            if let i = guests.firstIndex(where: { $0.id == e.guest.id }) {
                guests[i].salutation = after.salutation; guests[i].name = after.name; guests[i].withFamily = after.withFamily
                guests[i].invitedCount = after.invitedCount; guests[i].phoneE164 = after.phoneE164; guests[i].side = after.side
                guests[i].tableNo = after.tableNo; guests[i].lang = after.lang
            }
            editing = nil
            message = .saved
        case let .failure(err):
            e.saving = false; editing = e
            actionError = err
        }
    }

    // MARK: delete (owner)

    func askDelete(_ ids: [String]) { if isOwner, !ids.isEmpty { confirmDelete = ids } }

    func performDelete() async {
        guard let ids = confirmDelete else { return }
        busy = true
        let r = await repo.delete(ids)
        busy = false
        confirmDelete = nil
        switch r {
        case .success:
            guests.removeAll { ids.contains($0.id) }
            selected.subtract(ids)
            editing = nil
            message = .deleted
        case let .failure(err): actionError = err
        }
    }

    // MARK: bulk table / side

    func bulkTable(_ table: String) async {
        let t = String(table.trimmed.prefix(GuestRules.maxTable))
        await bulk("table_no", t.isEmpty ? nil : t) { g, v in g.tableNo = v }
    }

    func bulkSide(_ side: Side) async { await bulk("side", side.rawValue) { g, _ in g.side = side } }

    private func bulk(_ column: String, _ value: String?, apply: (inout Guest, String?) -> Void) async {
        let ids = Array(selected)
        guard !ids.isEmpty else { return }
        busy = true
        let r = await repo.bulkUpdate(ids, column: column, value: value)
        busy = false
        bulkTable = false
        switch r {
        case .success:
            for i in guests.indices where ids.contains(guests[i].id) { apply(&guests[i], value) }
            selected = []
            message = .saved
        case let .failure(err): actionError = err
        }
    }
}
