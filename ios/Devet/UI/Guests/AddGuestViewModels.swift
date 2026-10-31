import Foundation

// Screen [7] Add guests (spec/screens.md §7). Same behaviour as the Android view models: the three tabs share the
// event context — existing phones (duplicate warning), the event language (preview) and the server limit.

/// Limit sheet: the whole batch was refused; the tab keeps its data so it can be sent again after a purchase.
struct LimitHit: Equatable, Identifiable {
    let limit: Int?
    var id: Int { limit ?? -1 }
}

/// Phone field state under the input.
enum PhoneIssue { case none, invalid, notMobile }

func phoneIssue(_ phones: Phones, _ raw: String) -> (String?, PhoneIssue) {
    switch phones.normalize(raw) {
    case let .ok(e164): (e164, .none)
    case .error("empty"): (nil, .none)
    case .error("not_mobile"): (nil, .notMobile)
    case .error: (nil, .invalid)
    }
}

@MainActor
final class GuestContext {
    private let eventId: String
    private let guests: any GuestRepository
    private let events: any EventRepository
    private(set) var existing: [GuestPhone] = []
    private(set) var eventLang = "az"
    private var loaded = false

    init(eventId: String, guests: any GuestRepository, events: any EventRepository) {
        self.eventId = eventId
        self.guests = guests
        self.events = events
    }

    func load() async {
        guard !loaded else { return }
        loaded = true
        if case let .success(list) = await guests.phones(eventId) { existing = list }
        if case let .success(d) = await events.get(eventId) { eventLang = d.defaultLang }
    }

    func ownerOf(_ e164: String?) -> String? { e164.flatMap { p in existing.first { $0.phoneE164 == p }?.name } }

    func add(_ list: [NewGuest]) async -> AddResult {
        let r = await guests.add(eventId, list)
        if case .added = r { existing += list.compactMap { g in g.phoneE164.map { GuestPhone(name: g.name, phoneE164: $0) } } }
        return r
    }
}

// MARK: - 7a Manual (and the form of §6.1)

struct GuestForm: Equatable {
    var salutation: Salutation = .none
    var name = ""
    var withFamily = false
    var count = 1
    var phone = ""
    var side: Side = .none
    var table = ""
    /// nil = event language.
    var lang: String?
}

@MainActor
final class ManualGuestViewModel: ObservableObject {
    @Published var form = GuestForm() { didSet { normalizeForm() } }
    @Published private(set) var eventLang = "az"
    @Published private(set) var saving = false
    @Published private(set) var attempted = false
    @Published private(set) var error: AuthFailure?
    @Published var limit: LimitHit?
    /// Display name of the guest just added ("… əlavə olundu").
    @Published var added: String?
    @Published private(set) var done = false
    @Published private(set) var duplicateOf: String?
    @Published private(set) var phoneProblem: PhoneIssue = .none

    let ctx: GuestContext
    let spec: GuestSpec

    init(ctx: GuestContext, spec: GuestSpec) {
        self.ctx = ctx
        self.spec = spec
    }

    var nameError: Bool { attempted && !GuestRules.nameOK(form.name) }
    var canSave: Bool { GuestRules.nameOK(form.name) && phoneProblem == .none && GuestRules.tableOK(form.table) && !saving }

    func load() async {
        await ctx.load()
        eventLang = ctx.eventLang
    }

    private func normalizeForm() {
        if form.name.count > GuestRules.maxName { form.name = String(form.name.prefix(GuestRules.maxName)) }
        if form.table.count > GuestRules.maxTable { form.table = String(form.table.prefix(GuestRules.maxTable)) }
        let clamped = min(max(form.count, 1), GuestRules.maxCount)
        if clamped != form.count { form.count = clamped }
        let (e164, issue) = phoneIssue(spec.phones, form.phone)
        phoneProblem = issue
        duplicateOf = ctx.ownerOf(e164)
        error = nil
    }

    /// "Yadda saxla və növbəti": the form clears; side, table and language stay (screens.md §7a).
    func save(andNext: Bool) async {
        guard canSave else { attempted = true; return }
        let f = form
        let guest = NewGuest(name: f.name.trimmed, salutation: f.salutation, withFamily: f.withFamily, invitedCount: f.count,
                             phoneE164: phoneIssue(spec.phones, f.phone).0, side: f.side, tableNo: f.table.trimmed.isEmpty ? nil : f.table.trimmed, lang: f.lang)
        saving = true; attempted = true
        let r = await ctx.add([guest])
        saving = false
        switch r {
        case .added:
            attempted = false
            done = !andNext
            if andNext { form = GuestForm(side: f.side, table: f.table, lang: f.lang) }
            added = spec.displayNames.displayName(guest.name, guest.salutation, withFamily: guest.withFamily, lang: f.lang ?? eventLang)
        case let .limitExceeded(n): limit = LimitHit(limit: n)
        case let .failed(e): error = e
        }
    }
}

// MARK: - 7b Contacts

struct PickedContact: Identifiable, Equatable {
    let id: Int
    var name: String
    var phoneE164: String?
    /// The picked contact had no usable mobile number → added without a phone (§15.7).
    var noMobile: Bool
    var salutation: Salutation = .none
    var count = 1
    var duplicateOf: String?
}

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published private(set) var picked: [PickedContact] = []
    @Published private(set) var saving = false
    @Published private(set) var error: AuthFailure?
    @Published var limit: LimitHit?
    @Published var addedCount: Int?
    /// A contact with several mobile numbers waits here for the choice dialog (§15.7).
    @Published var choosing: (name: String, numbers: [String])?

    let ctx: GuestContext
    let spec: GuestSpec
    private var nextId = 0

    init(ctx: GuestContext, spec: GuestSpec) {
        self.ctx = ctx
        self.spec = spec
    }

    func load() async { await ctx.load() }

    /// iOS picker returns whole contacts: one mobile → taken, several → choice dialog, none → added without phone.
    func picked(name: String, numbers: [String]) {
        let mobiles = numbers.filter { phoneIssue(spec.phones, $0).0 != nil }
        if mobiles.count > 1 { choosing = (name, mobiles); return }
        add(name: name, number: mobiles.first)
    }

    func add(name: String, number: String?) {
        let e164 = number.flatMap { phoneIssue(spec.phones, $0).0 }
        picked.append(PickedContact(id: nextId, name: String(name.trimmed.prefix(GuestRules.maxName)), phoneE164: e164, noMobile: e164 == nil, duplicateOf: ctx.ownerOf(e164)))
        nextId += 1
        error = nil
    }

    func edit(_ id: Int, _ change: (inout PickedContact) -> Void) {
        guard let i = picked.firstIndex(where: { $0.id == id }) else { return }
        change(&picked[i])
        picked[i].count = min(max(picked[i].count, 1), GuestRules.maxCount)
    }

    func remove(_ id: Int) { picked.removeAll { $0.id == id } }

    func addAll() async {
        let list = picked.filter { GuestRules.nameOK($0.name) }
        guard !list.isEmpty, !saving else { return }
        saving = true; error = nil
        let r = await ctx.add(list.map { NewGuest(name: $0.name, salutation: $0.salutation, invitedCount: $0.count, phoneE164: $0.phoneE164) })
        saving = false
        switch r {
        case let .added(n): picked = []; addedCount = n
        case let .limitExceeded(n): limit = LimitHit(limit: n)
        case let .failed(e): error = e
        }
    }
}

// MARK: - 7c Excel

struct ErrorRow: Equatable { let sheetRow: Int; let codes: [String] }

struct ExcelMapping: Equatable {
    let fileName: String
    let headers: [String]
    let rows: [[ExcelRules.Cell]]
    /// Column index → field (absent = ignored).
    var columns: [Int: String]
    var hasName: Bool { columns.values.contains("name") }
}

struct ExcelSummary: Equatable {
    let mapping: ExcelMapping
    let guests: [NewGuest]
    let errors: [ErrorRow]
    let duplicates: Int
    var importing = false
}

enum ExcelStep: Equatable {
    case pick
    case reading
    /// `excel.file_error` or `excel.no_rows`.
    case fileError(noRows: Bool)
    case mapping(ExcelMapping)
    case summary(ExcelSummary)
}

@MainActor
final class ExcelImportViewModel: ObservableObject {
    @Published private(set) var step: ExcelStep = .pick
    @Published private(set) var error: AuthFailure?
    @Published var limit: LimitHit?
    @Published var addedCount: Int?

    let ctx: GuestContext
    let spec: GuestSpec

    init(ctx: GuestContext, spec: GuestSpec) {
        self.ctx = ctx
        self.spec = spec
    }

    func load() async { await ctx.load() }

    func open(fileName: String, data: @escaping @Sendable () throws -> Data) async {
        step = .reading; error = nil
        let rows = await Task.detached { try? XlsxReader.read(data()) }.value
        step = mappingFor(fileName, rows)
    }

    /// Header row → automatic column mapping (excel.json aliases); the user can change it.
    func mappingFor(_ fileName: String, _ rows: [[ExcelRules.Cell]]?) -> ExcelStep {
        guard let rows else { return .fileError(noRows: false) }
        let headers = rows.first?.map(ExcelRules.asText) ?? []
        let data = Array(rows.dropFirst())
        if !data.contains(where: { $0.contains { !ExcelRules.isEmpty($0) } }) { return .fileError(noRows: true) }
        // Without a name column the screen opens with what could be matched; the user picks the name column.
        let auto = spec.excel.mapHeadersPartial(headers)
        return .mapping(ExcelMapping(fileName: fileName, headers: headers, rows: data, columns: Dictionary(uniqueKeysWithValues: auto.map { ($0.value, $0.key) })))
    }

    func setColumn(_ column: Int, _ field: String?) {
        guard case var .mapping(m) = step else { return }
        m.columns = m.columns.filter { $0.value != field }
        m.columns[column] = field
        step = .mapping(m)
    }

    func toSummary() {
        guard case let .mapping(m) = step, m.hasName else { return }
        let results = m.rows.map { row in
            spec.excel.parseRow(Dictionary(uniqueKeysWithValues: m.columns.map { col, field in (field, col < row.count ? row[col] : .empty) }))
        }
        var guests: [NewGuest] = []
        var errors: [ErrorRow] = []
        for (i, r) in results.enumerated() {
            switch r {
            case let .ok(g): guests.append(g)
            // Row numbers as the family sees them in Excel (header is row 1).
            case let .errors(codes): errors.append(ErrorRow(sheetRow: i + 2, codes: codes))
            case .skipped: break
            }
        }
        let inFile = spec.excel.duplicateWarnings(results).count
        let inEvent = guests.filter { ctx.ownerOf($0.phoneE164) != nil }.count
        step = guests.isEmpty && errors.isEmpty ? .fileError(noRows: true) : .summary(ExcelSummary(mapping: m, guests: guests, errors: errors, duplicates: inFile + inEvent))
    }

    func backToMapping() { if case let .summary(s) = step { step = .mapping(s.mapping) } }
    func restart() { step = .pick; error = nil }

    /// One request for all rows; on a limit refusal the summary stays so the import can be repeated (§7).
    func importAll() async {
        guard case var .summary(s) = step, !s.guests.isEmpty, !s.importing else { return }
        s.importing = true
        step = .summary(s); error = nil
        let r = await ctx.add(s.guests)
        s.importing = false
        switch r {
        case let .added(n): step = .pick; addedCount = n
        case let .limitExceeded(n): step = .summary(s); limit = LimitHit(limit: n)
        case let .failed(e): step = .summary(s); error = e
        }
    }
}
