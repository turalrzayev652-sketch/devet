import Foundation
import Supabase

/// Guest status shown as a pill (spec/design.md §2.2, api.md §0.3).
enum GuestStatus { case coming, declined, viewed, pending, unsent }

/// A guest row of screen [6] (api.md §1 Guest). Same as Android `Guest`.
struct Guest: Identifiable, Equatable, Decodable {
    let id: String
    var code: String
    var salutation: Salutation
    var name: String
    var withFamily: Bool
    var invitedCount: Int
    var phoneE164: String?
    var side: Side
    var tableNo: String?
    var lang: String?
    var sentAt: String?
    var openedAt: String?
    var rsvpStatus: String
    var rsvpCount: Int

    /// yes → coming, no → declined; pending with opened_at → viewed, with sent_at → pending, else unsent.
    var status: GuestStatus {
        if rsvpStatus == "yes" { return .coming }
        if rsvpStatus == "no" { return .declined }
        if openedAt != nil { return .viewed }
        if sentAt != nil { return .pending }
        return .unsent
    }

    /// The editable part (screens.md §6.1).
    var fields: NewGuest {
        NewGuest(name: name, salutation: salutation, withFamily: withFamily, invitedCount: invitedCount, phoneE164: phoneE164, side: side, tableNo: tableNo, lang: lang)
    }

    enum CodingKeys: String, CodingKey {
        case id, code, salutation, name, side, lang
        case withFamily = "with_family", invitedCount = "invited_count", phoneE164 = "phone_e164", tableNo = "table_no"
        case sentAt = "sent_at", openedAt = "opened_at", rsvpStatus = "rsvp_status", rsvpCount = "rsvp_count"
    }

    init(id: String, code: String, salutation: Salutation, name: String, withFamily: Bool, invitedCount: Int, phoneE164: String?,
         side: Side, tableNo: String?, lang: String?, sentAt: String?, openedAt: String?, rsvpStatus: String, rsvpCount: Int) {
        self.id = id; self.code = code; self.salutation = salutation; self.name = name; self.withFamily = withFamily
        self.invitedCount = invitedCount; self.phoneE164 = phoneE164; self.side = side; self.tableNo = tableNo; self.lang = lang
        self.sentAt = sentAt; self.openedAt = openedAt; self.rsvpStatus = rsvpStatus; self.rsvpCount = rsvpCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        salutation = Salutation(rawValue: try c.decodeIfPresent(String.self, forKey: .salutation) ?? "none") ?? .none
        name = try c.decode(String.self, forKey: .name)
        withFamily = try c.decodeIfPresent(Bool.self, forKey: .withFamily) ?? false
        invitedCount = try c.decodeIfPresent(Int.self, forKey: .invitedCount) ?? 1
        phoneE164 = try c.decodeIfPresent(String.self, forKey: .phoneE164)
        side = Side(rawValue: try c.decodeIfPresent(String.self, forKey: .side) ?? "none") ?? .none
        tableNo = try c.decodeIfPresent(String.self, forKey: .tableNo)
        lang = try c.decodeIfPresent(String.self, forKey: .lang)
        sentAt = try c.decodeIfPresent(String.self, forKey: .sentAt)
        openedAt = try c.decodeIfPresent(String.self, forKey: .openedAt)
        rsvpStatus = try c.decodeIfPresent(String.self, forKey: .rsvpStatus) ?? "pending"
        rsvpCount = try c.decodeIfPresent(Int.self, forKey: .rsvpCount) ?? 0
    }
}

/// Columns the edit sheet may change (api.md §9 guests update), only those that differ. Same as Android.
func guestChanges(_ before: NewGuest, _ after: NewGuest) -> [String: AnyJSON] {
    func columns(_ g: NewGuest) -> [String: AnyJSON] {
        func str(_ v: String?) -> AnyJSON { v.map { .string($0) } ?? .null }
        let table = g.tableNo?.trimmed
        return [
            "salutation": .string(g.salutation.rawValue), "name": .string(g.name.trimmed), "with_family": .bool(g.withFamily),
            "invited_count": .integer(g.invitedCount), "phone_e164": str(g.phoneE164), "side": .string(g.side.rawValue),
            "table_no": str(table?.isEmpty == true ? nil : table), "lang": str(g.lang),
        ]
    }
    let b = columns(before)
    return columns(after).filter { b[$0.key] != $0.value }
}

/// Screen [6] calls (api.md §2 [6]).
protocol GuestListRepository: Sendable {
    func list(_ eventId: String) async -> Result<[Guest], AuthFailure>
    /// `event_guest_limit(event_id)`; nil when the user is not a member.
    func limit(_ eventId: String) async -> Result<Int?, AuthFailure>
    /// PATCH with the changed columns only; 0 rows → `.forbidden`.
    func update(_ id: String, before: NewGuest, after: NewGuest) async -> Result<Void, AuthFailure>
    /// Several guests at once: `table_no` or `side` (screens.md §6 bulk panel).
    func bulkUpdate(_ ids: [String], column: String, value: String?) async -> Result<Void, AuthFailure>
    /// Owner only; a co-host gets 0 rows → `.forbidden`.
    func delete(_ ids: [String]) async -> Result<Void, AuthFailure>
    /// Mark guest as sent (T48: set sent_at to now).
    func markSent(_ id: String) async -> Result<Void, AuthFailure>
}

final class SupabaseGuestListRepository: GuestListRepository {
    private let client: SupabaseClient?
    private struct IdRow: Decodable { let id: String }

    init(client: SupabaseClient?) {
        self.client = client
    }

    func list(_ eventId: String) async -> Result<[Guest], AuthFailure> {
        await call { client in try await client.from("guests").select().eq("event_id", value: eventId).order("name", ascending: true).execute().value }
    }

    func limit(_ eventId: String) async -> Result<Int?, AuthFailure> {
        await call { client in try await client.rpc("event_guest_limit", params: ["p_event_id": eventId]).execute().value }
    }

    func update(_ id: String, before: NewGuest, after: NewGuest) async -> Result<Void, AuthFailure> {
        let changes = guestChanges(before, after)
        if changes.isEmpty { return client == nil ? .failure(.notConfigured) : .success(()) }
        return await call { client in
            let rows: [IdRow] = try await client.from("guests").update(changes).eq("id", value: id).select("id").execute().value
            if rows.isEmpty { throw AuthFailure.forbidden }
        }
    }

    func bulkUpdate(_ ids: [String], column: String, value: String?) async -> Result<Void, AuthFailure> {
        precondition(column == "table_no" || column == "side")
        if ids.isEmpty { return .success(()) }
        return await call { client in
            let body: [String: AnyJSON] = [column: value.map { .string($0) } ?? .null]
            let rows: [IdRow] = try await client.from("guests").update(body).in("id", values: ids).select("id").execute().value
            if rows.isEmpty { throw AuthFailure.forbidden }
        }
    }

    func delete(_ ids: [String]) async -> Result<Void, AuthFailure> {
        if ids.isEmpty { return .success(()) }
        return await call { client in
            let rows: [IdRow] = try await client.from("guests").delete().in("id", values: ids).select("id").execute().value
            if rows.isEmpty { throw AuthFailure.forbidden }
        }
    }

    func markSent(_ id: String) async -> Result<Void, AuthFailure> {
        return await call { client in
            let now = ISO8601DateFormatter().string(from: Date())
            let rows: [IdRow] = try await client.from("guests").update(["sent_at": now]).eq("id", value: id).select("id").execute().value
            if rows.isEmpty { throw AuthFailure.forbidden }
        }
    }

    private func call<T>(_ block: (SupabaseClient) async throws -> T) async -> Result<T, AuthFailure> {
        guard let client else { return .failure(.notConfigured) }
        return await runAuth { try await block(client) }
    }
}
