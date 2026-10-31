package az.devet.app.data.account

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.runAuth
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `profiles` row (spec/PRODUCT.md §5); only display_name and ui_lang are writable (api.md §9). */
@Serializable
data class Profile(
    val id: String,
    val email: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("ui_lang") val uiLang: String = "az",
)

/** Screen [12b] calls (spec/api.md §2 [12b], §6.2). */
interface AccountRepository {
    suspend fun profile(): AuthResult<Profile>
    suspend fun updateName(name: String): AuthResult<Unit>
    suspend fun updateLanguage(lang: String): AuthResult<Unit>

    /** `delete-account` Edge Function; the caller signs out on success. */
    suspend fun deleteAccount(): AuthResult<Unit>
}

class SupabaseAccountRepository(private val client: SupabaseClient?) : AccountRepository {

    override suspend fun profile() = call {
        from("profiles").select().decodeSingle<Profile>()
    }

    override suspend fun updateName(name: String) = update("display_name", name.trim())

    override suspend fun updateLanguage(lang: String) = update("ui_lang", lang)

    override suspend fun deleteAccount() = call {
        // Non-2xx answers (storage_unavailable, delete_failed — both "try again") throw and map to an error.
        functions.invoke("delete-account")
        Unit
    }

    private suspend fun update(column: String, value: String) = call {
        val uid = auth.currentUserOrNull()?.id ?: throw IllegalStateException("not signed in")
        from("profiles").update({ set(column, value) }) { filter { eq("id", uid) } }
        Unit
    }

    private suspend fun <T> call(block: suspend SupabaseClient.() -> T): AuthResult<T> {
        val c = client ?: return AuthResult.Failure(AuthError.NotConfigured)
        return runAuth { c.block() }
    }
}
