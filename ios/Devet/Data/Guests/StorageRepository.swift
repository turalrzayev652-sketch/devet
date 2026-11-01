import Foundation
import Supabase

/// Dəvətnamə şəkilləri və media Supabase Storage-ə yükləmək.
protocol StorageRepository: Sendable {
    func uploadPreviewImage(_ bytes: Data, code: String, eventId: String) async -> Result<String, AuthFailure>
}

/// Supabase Storage implementation (previews bucket).
final class SupabaseStorageRepository: StorageRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func uploadPreviewImage(_ bytes: Data, code: String, eventId: String) async -> Result<String, AuthFailure> {
        guard let client else { return .failure(.notConfigured) }

        return await runAuth {
            let path = "\(code).jpg"
            _ = try await client.storage
                .from("previews")
                .update(path, data: bytes, options: FileOptions(upsert: true))
            return path
        }
    }
}
