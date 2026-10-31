import Foundation
import Supabase

/// `profiles` row (spec/PRODUCT.md §5); only display_name and ui_lang are writable (api.md §9).
struct Profile: Decodable, Equatable {
    let id: String
    var email: String?
    var displayName: String?
    var uiLang: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case uiLang = "ui_lang"
    }
}

/// Screen [12b] calls (spec/api.md §2 [12b], §6.2).
protocol AccountRepository: Sendable {
    func profile() async -> Result<Profile, AuthFailure>
    func updateName(_ name: String) async -> Result<Void, AuthFailure>
    func updateLanguage(_ lang: String) async -> Result<Void, AuthFailure>
    /// `delete-account` Edge Function; the caller signs out on success.
    func deleteAccount() async -> Result<Void, AuthFailure>
}

final class SupabaseAccountRepository: AccountRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func profile() async -> Result<Profile, AuthFailure> {
        await call { client in
            try await client.from("profiles").select().single().execute().value
        }
    }

    func updateName(_ name: String) async -> Result<Void, AuthFailure> { await update("display_name", name.trimmed) }

    func updateLanguage(_ lang: String) async -> Result<Void, AuthFailure> { await update("ui_lang", lang) }

    func deleteAccount() async -> Result<Void, AuthFailure> {
        // Non-2xx answers (storage_unavailable, delete_failed — both "try again") throw and map to an error.
        await call { client in try await client.functions.invoke("delete-account") }
    }

    private func update(_ column: String, _ value: String) async -> Result<Void, AuthFailure> {
        await call { client in
            guard let uid = client.auth.currentUser?.id else { throw AuthFailure.unauthorized }
            try await client.from("profiles").update([column: value]).eq("id", value: uid).execute()
        }
    }

    private func call<T>(_ block: (SupabaseClient) async throws -> T) async -> Result<T, AuthFailure> {
        guard let client else { return .failure(.notConfigured) }
        return await runAuth { try await block(client) }
    }
}
