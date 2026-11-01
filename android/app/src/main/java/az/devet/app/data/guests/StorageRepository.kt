package az.devet.app.data.guests

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.UUID

/// Dəvətnamə şəkilləri və media Supabase Storage-ə yükləmək.
interface StorageRepository {
    suspend fun uploadPreviewImage(bytes: ByteArray, code: String, eventId: String): AuthResult<String>
}

class SupabaseStorageRepository(private val client: SupabaseClient?) : StorageRepository {
    override suspend fun uploadPreviewImage(bytes: ByteArray, code: String, eventId: String): AuthResult<String> = withContext(Dispatchers.IO) {
        guard { client } ?: return@withContext AuthResult.Failure(AuthError.NotConfigured)

        runAuth {
            val bucket = client.storage.from("previews")
            val path = "$code.jpg"
            bucket.upload(path, bytes, upsert = true)
            path  // return the path for later reference
        }
    }

    private fun <T> guard(block: () -> T?): T? = block()
}
