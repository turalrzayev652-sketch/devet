import Foundation
import Supabase

/// Existing guest phone → name, for the duplicate warning (screens.md §7).
struct GuestPhone: Equatable { let name: String; let phoneE164: String }

/// Result of adding guests (same as Android `AddResult`).
enum AddResult: Equatable {
    case added(Int)
    /// Server trigger refused the whole batch (api.md §5); limit from `detail: limit=N`.
    case limitExceeded(Int?)
    case failed(AuthFailure)
}

/// Screen [7] calls (api.md §2 [7]).
protocol GuestRepository: Sendable {
    func phones(_ eventId: String) async -> Result<[GuestPhone], AuthFailure>
    func count(_ eventId: String) async -> Result<Int, AuthFailure>
    /// One request for the whole batch: the server takes all or nothing.
    func add(_ eventId: String, _ guests: [NewGuest]) async -> AddResult
}

extension NewGuest {
    func json(eventId: String) -> [String: AnyJSON] {
        func opt(_ s: String?) -> AnyJSON { s.map { .string($0) } ?? .null }
        let table = tableNo?.trimmed
        return [
            "event_id": .string(eventId), "salutation": .string(salutation.rawValue), "name": .string(name.trimmed),
            "with_family": .bool(withFamily), "invited_count": .integer(invitedCount), "phone_e164": opt(phoneE164),
            "side": .string(side.rawValue), "table_no": opt(table?.isEmpty == true ? nil : table), "lang": opt(lang),
        ]
    }
}

/// `P0001 guest_limit_exceeded` with `detail: limit=N` (api.md §0.2).
func limitFrom(_ error: Error) -> AddResult? {
    guard let p = error as? PostgrestError else { return nil }
    let text = [p.code, p.message, p.details, p.hint].compactMap { $0 }.joined(separator: " ")
    guard text.contains("guest_limit_exceeded") else { return nil }
    let limit = text.range(of: #"limit=(\d+)"#, options: .regularExpression).flatMap { Int(text[$0].dropFirst(6)) }
    return .limitExceeded(limit)
}

final class SupabaseGuestRepository: GuestRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    private struct Row: Decodable { let name: String; let phone_e164: String? }
    private struct IdRow: Decodable { let id: String }

    func phones(_ eventId: String) async -> Result<[GuestPhone], AuthFailure> {
        await call { client in
            let rows: [Row] = try await client.from("guests").select("name,phone_e164").eq("event_id", value: eventId).execute().value
            return rows.compactMap { r in r.phone_e164.map { GuestPhone(name: r.name, phoneE164: $0) } }
        }
    }

    func count(_ eventId: String) async -> Result<Int, AuthFailure> {
        await call { client in
            let rows: [IdRow] = try await client.from("guests").select("id").eq("event_id", value: eventId).execute().value
            return rows.count
        }
    }

    func add(_ eventId: String, _ guests: [NewGuest]) async -> AddResult {
        guard let client else { return .failed(.notConfigured) }
        if guests.isEmpty { return .added(0) }
        do {
            let _: [IdRow] = try await client.from("guests").insert(guests.map { $0.json(eventId: eventId) }, returning: .representation)
                .select("id").execute().value
            return .added(guests.count)
        } catch {
            return limitFrom(error) ?? .failed(AuthFailure.from(error))
        }
    }

    private func call<T>(_ block: (SupabaseClient) async throws -> T) async -> Result<T, AuthFailure> {
        guard let client else { return .failure(.notConfigured) }
        return await runAuth { try await block(client) }
    }
}
