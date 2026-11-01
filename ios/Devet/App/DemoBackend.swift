#if DEBUG
import Foundation

// Debug-only demo backend (launch argument `-DevetDemo YES`): signed in, events kept in memory. Lets screens be
// tried on a simulator before a Supabase project exists. Same sample data as Android's DemoModule; not compiled
// into release builds.

final class DemoAuth: AuthRepository, @unchecked Sendable {
    private var continuation: AsyncStream<SessionState>.Continuation?
    func sessionStates() -> AsyncStream<SessionState> {
        AsyncStream { c in c.yield(.signedIn); continuation = c }
    }
    var currentEmail: String? { "demo@devet.az" }
    func signIn(email: String, password: String) async -> Result<Void, AuthFailure> { continuation?.yield(.signedIn); return .success(()) }
    func signUp(name: String, email: String, password: String) async -> Result<Bool, AuthFailure> { .success(true) }
    func resendConfirmation(email: String) async -> Result<Void, AuthFailure> { .success(()) }
    func sendPasswordReset(email: String) async -> Result<Void, AuthFailure> { .success(()) }
    func exchangeCode(_ code: String) async -> Result<Void, AuthFailure> { .success(()) }
    func updatePassword(_ password: String) async -> Result<Void, AuthFailure> { .success(()) }
    func signOut() async { continuation?.yield(.signedOut) }
}

final class DemoAccount: AccountRepository, @unchecked Sendable {
    func profile() async -> Result<Profile, AuthFailure> { .success(Profile(id: "demo", email: "demo@devet.az", displayName: "Aysel", uiLang: "az")) }
    func updateName(_ name: String) async -> Result<Void, AuthFailure> { .success(()) }
    func updateLanguage(_ lang: String) async -> Result<Void, AuthFailure> { .success(()) }
    func deleteAccount() async -> Result<Void, AuthFailure> { .success(()) }
}

final class DemoEvents: EventRepository, @unchecked Sendable {
    private struct Item { var draft: EventDraft; let role: MemberRole; let guests: Int; let coming: Int; let noAnswer: Int }
    private var order = ["demo-1", "demo-2", "demo-3"]
    private var items: [String: Item]

    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = EventRules.zone
        func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }
        items = [
            "demo-1": Item(draft: EventDraft(type: .wedding, titleNames: "Aysel və Ramin", hostNames: "Məmmədovlar və Əliyevlər ailələri",
                startsAt: at(2027, 7, 12, 18), venueName: "Ağ Saray şadlıq evi", venueAddress: "Bakı, Nərimanov r-nu",
                mapsURL: "https://maps.google.com/?q=40.4093,49.8671"), role: .owner, guests: 212, coming: 121, noAnswer: 59),
            "demo-2": Item(draft: EventDraft(type: .birthday, titleNames: "Nərminin ad günü", startsAt: at(2027, 8, 3, 17),
                venueName: "Mərcan restoranı", defaultLang: "ru", showTablemates: true), role: .cohost, guests: 40, coming: 22, noAnswer: 14),
            "demo-3": Item(draft: EventDraft(type: .engagement, titleNames: "Leyla və Tural", startsAt: Date().addingTimeInterval(-30 * 86400),
                venueName: "Gülüstan sarayı"), role: .owner, guests: 80, coming: 64, noAnswer: 0),
        ]
    }

    func list() async -> Result<[EventSummary], AuthFailure> {
        .success(order.compactMap { id in
            items[id].map { EventSummary(id: id, type: $0.draft.type!, titleNames: $0.draft.titleNames, startsAt: $0.draft.startsAt!,
                venueName: $0.draft.venueName, thumbnailURL: nil, role: $0.role, guestCount: $0.guests, comingPeople: $0.coming, noAnswer: $0.noAnswer) }
        })
    }
    func get(_ id: String) async -> Result<EventDraft, AuthFailure> { items[id].map { .success($0.draft) } ?? .failure(.unknown) }
    func create(_ draft: EventDraft) async -> Result<String, AuthFailure> {
        let id = UUID().uuidString
        items[id] = Item(draft: draft, role: .owner, guests: 0, coming: 0, noAnswer: 0)
        order.append(id)
        return .success(id)
    }
    func update(_ id: String, before: EventDraft, after: EventDraft) async -> Result<Void, AuthFailure> {
        items[id]?.draft = after
        return .success(())
    }
    func delete(_ id: String) async -> Result<Void, AuthFailure> {
        if items[id]?.role == .cohost { return .failure(.forbidden) }
        items[id] = nil
        order.removeAll { $0 == id }
        return .success(())
    }
}
/// In-memory guests with the free limit (100), so the limit sheet can be tried too; one demo event has guests.
final class DemoGuests: GuestRepository, GuestListRepository, @unchecked Sendable {
    static let shared = DemoGuests()
    private var byEvent: [String: [Guest]] = [:]
    private var nextId = 0

    init() {
        let sample: [(NewGuest, String, Int, Bool, Bool)] = [
            (NewGuest(name: "Elçin", salutation: .muellim, withFamily: true, invitedCount: 4, phoneE164: "+994501234567", side: .groom, tableNo: "12"), "yes", 4, true, false),
            (NewGuest(name: "Leyla", salutation: .xanim, phoneE164: "+994551112233", side: .bride, tableNo: "7"), "pending", 0, true, false),
            (NewGuest(name: "Rəşad", salutation: .bey, invitedCount: 2, phoneE164: "+994701234567", side: .groom), "no", 0, true, false),
            (NewGuest(name: "Nərmin", salutation: .xanim, withFamily: true, invitedCount: 3, side: .bride, tableNo: "7"), "pending", 0, true, true),
            (NewGuest(name: "Kamran", phoneE164: "+994771234567", tableNo: "3", lang: "ru"), "pending", 0, false, false),
        ]
        byEvent["demo-1"] = sample.map { g, rsvp, count, sent, opened in
            var guest = make(g)
            guest.rsvpStatus = rsvp; guest.rsvpCount = count
            guest.sentAt = sent ? "2027-06-01T10:00:00Z" : nil
            guest.openedAt = opened ? "2027-06-02T10:00:00Z" : nil
            return guest
        }
    }

    private func make(_ g: NewGuest) -> Guest {
        nextId += 1
        return Guest(id: "g\(nextId)", code: "CODE\(nextId)", salutation: g.salutation, name: g.name, withFamily: g.withFamily, invitedCount: g.invitedCount,
                     phoneE164: g.phoneE164, side: g.side, tableNo: g.tableNo, lang: g.lang, sentAt: nil, openedAt: nil, rsvpStatus: "pending", rsvpCount: 0)
    }

    func phones(_ eventId: String) async -> Result<[GuestPhone], AuthFailure> {
        .success((byEvent[eventId] ?? []).compactMap { g in g.phoneE164.map { GuestPhone(name: g.name, phoneE164: $0) } })
    }
    func count(_ eventId: String) async -> Result<Int, AuthFailure> { .success(byEvent[eventId]?.count ?? 0) }
    func add(_ eventId: String, _ guests: [NewGuest]) async -> AddResult {
        if (byEvent[eventId]?.count ?? 0) + guests.count > 100 { return .limitExceeded(100) }
        byEvent[eventId, default: []] += guests.map(make)
        return .added(guests.count)
    }

    func list(_ eventId: String) async -> Result<[Guest], AuthFailure> { .success((byEvent[eventId] ?? []).sorted { $0.name < $1.name }) }
    func limit(_ eventId: String) async -> Result<Int?, AuthFailure> { .success(100) }
    func update(_ id: String, before: NewGuest, after: NewGuest) async -> Result<Void, AuthFailure> {
        for (event, list) in byEvent {
            byEvent[event] = list.map { g in
                guard g.id == id else { return g }
                var n = g
                n.salutation = after.salutation; n.name = after.name; n.withFamily = after.withFamily; n.invitedCount = after.invitedCount
                n.phoneE164 = after.phoneE164; n.side = after.side; n.tableNo = after.tableNo; n.lang = after.lang
                return n
            }
        }
        return .success(())
    }
    func bulkUpdate(_ ids: [String], column: String, value: String?) async -> Result<Void, AuthFailure> {
        for (event, list) in byEvent {
            byEvent[event] = list.map { g in
                guard ids.contains(g.id) else { return g }
                var n = g
                if column == "side" { n.side = Side(rawValue: value ?? "none") ?? .none } else { n.tableNo = value }
                return n
            }
        }
        return .success(())
    }
    func delete(_ ids: [String]) async -> Result<Void, AuthFailure> {
        for (event, list) in byEvent { byEvent[event] = list.filter { !ids.contains($0.id) } }
        return .success(())
    }
}
#endif
