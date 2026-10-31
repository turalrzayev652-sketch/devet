import Foundation
import Supabase

/// `event_type` enum (PRODUCT.md §4).
enum EventType: String, CaseIterable, Identifiable {
    case wedding, engagement, henna, birthday, jubilee
    var id: String { rawValue }
    var labelKey: String { "event.type.\(rawValue)" }
}

enum MemberRole { case owner, cohost }

/// Event card on screen [2] (spec/api.md §2 [2]). Same fields as Android `EventSummary`.
struct EventSummary: Identifiable, Equatable, Hashable {
    let id: String
    let type: EventType
    let titleNames: String
    let startsAt: Date
    let venueName: String
    let thumbnailURL: String?
    let role: MemberRole
    let guestCount: Int
    /// People coming: sum of rsvp_count where rsvp_status = yes.
    let comingPeople: Int
    /// Guests with rsvp_status = pending.
    let noAnswer: Int
}

/// Form state of screen [3] — also the editable fields of an existing event.
struct EventDraft: Equatable {
    var type: EventType?
    var titleNames = ""
    var hostNames = ""
    var startsAt: Date?
    var venueName = ""
    var venueAddress = ""
    var mapsURL = ""
    var defaultLang = "az"
    var showTablemates = false
}

enum EventRules {
    static let maxTitle = 80
    static let maxHosts = 120
    static let maxVenue = 120

    /// Events are shown and entered in Baku time (spec/api.md §0.1).
    static let zone = TimeZone(identifier: "Asia/Baku")!
    /// An event moves to "Arxiv" 7 days after it starts (screens.md §15.2).
    static let archiveAfter: TimeInterval = 7 * 86400

    static func isArchivedByDate(_ startsAt: Date, now: Date) -> Bool { startsAt.addingTimeInterval(archiveAfter) < now }

    static func titleOK(_ v: String) -> Bool { (1...maxTitle).contains(v.trimmed.count) }
    static func hostsOK(_ v: String) -> Bool { v.trimmed.count <= maxHosts }
    static func venueOK(_ v: String) -> Bool { (1...maxVenue).contains(v.trimmed.count) }
    static func dateOK(_ v: Date?, now: Date) -> Bool { v.map { $0 > now } ?? false }
    static func mapsOK(_ v: String) -> Bool {
        if v.trimmed.isEmpty { return true }
        if case .ok = MapsLink.parse(v) { return true }
        return false
    }

    /// Wizard steps 1–6 (screens.md §3). Steps 5 and 6 always pass.
    static func stepValid(_ step: Int, _ d: EventDraft, now: Date) -> Bool {
        switch step {
        case 1: d.type != nil
        case 2: titleOK(d.titleNames) && hostsOK(d.hostNames)
        case 3: dateOK(d.startsAt, now: now)
        case 4: venueOK(d.venueName) && mapsOK(d.mapsURL)
        default: true
        }
    }

    /// "2027-07-12T18:00+04:00" — the same text Android sends.
    static func isoBaku(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = Calendar(identifier: .gregorian).dateComponents(in: zone, from: date).second == 0 ? "yyyy-MM-dd'T'HH:mmxxx" : "yyyy-MM-dd'T'HH:mm:ssxxx"
        return f.string(from: date)
    }

    /// Columns for insert / update (api.md §9). A link without readable coordinates stores null so an old pin
    /// never outlives a changed link.
    static func columns(_ d: EventDraft) -> [String: AnyJSON] {
        let maps = d.mapsURL.trimmed
        var lat: Double?, lng: Double?
        if case let .ok(la, ln) = MapsLink.parse(maps) { lat = la; lng = ln }
        func str(_ s: String?) -> AnyJSON { s.map { .string($0) } ?? .null }
        func num(_ v: Double?) -> AnyJSON { v.map { .double($0) } ?? .null }
        return [
            "type": str(d.type?.rawValue),
            "title_names": .string(d.titleNames.trimmed),
            "host_names": str(d.hostNames.trimmed.isEmpty ? nil : d.hostNames.trimmed),
            "starts_at": str(d.startsAt.map(isoBaku)),
            "venue_name": .string(d.venueName.trimmed),
            "venue_address": str(d.venueAddress.trimmed.isEmpty ? nil : d.venueAddress.trimmed),
            "maps_url": str(maps.isEmpty ? nil : maps),
            "venue_lat": num(lat),
            "venue_lng": num(lng),
            "default_lang": .string(d.defaultLang),
            "show_tablemates": .bool(d.showTablemates),
        ]
    }

    /// Only the changed columns for PATCH (api.md §2 [3]).
    static func changes(_ before: EventDraft, _ after: EventDraft) -> [String: AnyJSON] {
        let a = columns(before)
        return columns(after).filter { a[$0.key] != $0.value }
    }
}
