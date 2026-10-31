import Foundation
import Supabase

/// Screens [2] and [3] (spec/api.md §2 [2], [3]). RLS limits every call to the user's own events.
protocol EventRepository: Sendable {
    func list() async -> Result<[EventSummary], AuthFailure>
    func get(_ id: String) async -> Result<EventDraft, AuthFailure>
    /// Returns the new event id (the creator becomes owner by trigger).
    func create(_ draft: EventDraft) async -> Result<String, AuthFailure>
    /// PATCH with only the changed columns; nothing to send → success without a request.
    func update(_ id: String, before: EventDraft, after: EventDraft) async -> Result<Void, AuthFailure>
    /// Owner only: RLS returns 0 rows for a co-host → `.forbidden`.
    func delete(_ id: String) async -> Result<Void, AuthFailure>
}

struct EventRow: Decodable {
    let id: String
    let type: String
    let titleNames: String
    var hostNames: String?
    let startsAt: String
    let venueName: String
    var venueAddress: String?
    var mapsUrl: String?
    var defaultLang: String?
    var showTablemates: Bool?
    var templates: TemplateRef?
    var eventMembers: [MemberRow]?
    var guests: [GuestStat]?

    struct TemplateRef: Decodable {
        var thumbnailUrl: String?
        enum CodingKeys: String, CodingKey { case thumbnailUrl = "thumbnail_url" }
    }
    struct MemberRow: Decodable {
        let userId: String
        let role: String
        enum CodingKeys: String, CodingKey { case userId = "user_id", role }
    }
    struct GuestStat: Decodable {
        var rsvpStatus: String?
        var rsvpCount: Int?
        enum CodingKeys: String, CodingKey { case rsvpStatus = "rsvp_status", rsvpCount = "rsvp_count" }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, templates, guests
        case titleNames = "title_names", hostNames = "host_names", startsAt = "starts_at", venueName = "venue_name"
        case venueAddress = "venue_address", mapsUrl = "maps_url", defaultLang = "default_lang", showTablemates = "show_tablemates"
        case eventMembers = "event_members"
    }

    func summary(userId: String?) -> EventSummary {
        let g = guests ?? []
        let mine = eventMembers?.first { $0.userId.lowercased() == userId?.lowercased() }
        return EventSummary(
            id: id, type: EventType(rawValue: type) ?? .wedding, titleNames: titleNames, startsAt: parseTimestamp(startsAt),
            venueName: venueName, thumbnailURL: templates?.thumbnailUrl, role: mine?.role == "cohost" ? .cohost : .owner,
            guestCount: g.count,
            comingPeople: g.filter { $0.rsvpStatus == "yes" }.reduce(0) { $0 + ($1.rsvpCount ?? 0) },
            noAnswer: g.filter { ($0.rsvpStatus ?? "pending") == "pending" }.count
        )
    }

    var draft: EventDraft {
        EventDraft(
            type: EventType(rawValue: type) ?? .wedding, titleNames: titleNames, hostNames: hostNames ?? "", startsAt: parseTimestamp(startsAt),
            venueName: venueName, venueAddress: venueAddress ?? "", mapsURL: mapsUrl ?? "",
            defaultLang: defaultLang ?? "az", showTablemates: showTablemates ?? false
        )
    }
}

struct IdRow: Decodable { let id: String }

/// PostgREST timestamptz ("2027-07-12T14:00:00+00:00", optional fraction, space or T).
func parseTimestamp(_ s: String) -> Date {
    let text = s.replacingOccurrences(of: " ", with: "T")
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: text) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: text) ?? .distantPast
}

final class SupabaseEventRepository: EventRepository {
    private let client: SupabaseClient?

    static let listColumns = "id,type,title_names,starts_at,venue_name,template_id,status," +
        "templates(thumbnail_url),event_members(user_id,role),guests(rsvp_status,rsvp_count,sent_at,opened_at)"
    static let editColumns = "id,type,title_names,host_names,starts_at,venue_name,venue_address,maps_url,default_lang,show_tablemates"

    init(client: SupabaseClient?) {
        self.client = client
    }

    func list() async -> Result<[EventSummary], AuthFailure> {
        await call { client in
            let rows: [EventRow] = try await client.from("events").select(Self.listColumns).order("starts_at", ascending: true).execute().value
            let uid = client.auth.currentUser?.id.uuidString
            return rows.map { $0.summary(userId: uid) }
        }
    }

    func get(_ id: String) async -> Result<EventDraft, AuthFailure> {
        await call { client in
            let row: EventRow = try await client.from("events").select(Self.editColumns).eq("id", value: id).single().execute().value
            return row.draft
        }
    }

    func create(_ draft: EventDraft) async -> Result<String, AuthFailure> {
        await call { client in
            let row: IdRow = try await client.from("events").insert(EventRules.columns(draft), returning: .representation)
                .select("id").single().execute().value
            return row.id
        }
    }

    func update(_ id: String, before: EventDraft, after: EventDraft) async -> Result<Void, AuthFailure> {
        let changes = EventRules.changes(before, after)
        if changes.isEmpty { return client == nil ? .failure(.notConfigured) : .success(()) }
        return await call { client in
            let rows: [IdRow] = try await client.from("events").update(changes).eq("id", value: id).select("id").execute().value
            if rows.isEmpty { throw AuthFailure.forbidden }
        }
    }

    func delete(_ id: String) async -> Result<Void, AuthFailure> {
        await call { client in
            let rows: [IdRow] = try await client.from("events").delete().eq("id", value: id).select("id").execute().value
            if rows.isEmpty { throw AuthFailure.forbidden }
        }
    }

    private func call<T>(_ block: (SupabaseClient) async throws -> T) async -> Result<T, AuthFailure> {
        guard let client else { return .failure(.notConfigured) }
        return await runAuth { try await block(client) }
    }
}
