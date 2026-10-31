package az.devet.app.data.guests

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.runAuth
import az.devet.app.data.auth.toAuthError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Existing guest phone → name, for the duplicate warning (screens.md §7). */
data class GuestPhone(val name: String, val phoneE164: String)

/** Result of adding guests. */
sealed interface AddResult {
    data class Added(val count: Int) : AddResult
    /** Server trigger refused the whole batch (api.md §5); [limit] from `detail: limit=N`. */
    data class LimitExceeded(val limit: Int?) : AddResult
    data class Failed(val error: AuthError) : AddResult
}

/** Screen [7] calls (api.md §2 [7]). */
interface GuestRepository {
    /** Phones already in the event (and the guest count), for duplicate warnings and the event home. */
    suspend fun phones(eventId: String): AuthResult<List<GuestPhone>>
    suspend fun count(eventId: String): AuthResult<Int>

    /** One request for the whole batch: the server takes all or nothing. */
    suspend fun add(eventId: String, guests: List<NewGuest>): AddResult
}

@Serializable
internal data class GuestPhoneRow(val name: String, val phone_e164: String? = null)

internal fun NewGuest.toJson(eventId: String) = buildJsonObject {
    put("event_id", eventId)
    put("salutation", salutation.key)
    put("name", name.trim())
    put("with_family", withFamily)
    put("invited_count", invitedCount)
    put("phone_e164", phoneE164?.let(::JsonPrimitive) ?: JsonNull)
    put("side", side.key)
    put("table_no", tableNo?.trim()?.ifEmpty { null }?.let(::JsonPrimitive) ?: JsonNull)
    put("lang", lang?.let(::JsonPrimitive) ?: JsonNull)
}

/** `P0001 guest_limit_exceeded` with `detail: limit=N` (api.md §0.2). */
internal fun limitFrom(e: RestException): AddResult.LimitExceeded? {
    val text = listOfNotNull(e.error, e.description, e.message).joinToString(" ")
    if (!text.contains("guest_limit_exceeded")) return null
    return AddResult.LimitExceeded(Regex("""limit=(\d+)""").find(text)?.groupValues?.get(1)?.toIntOrNull())
}

class SupabaseGuestRepository(private val client: SupabaseClient?) : GuestRepository {

    override suspend fun phones(eventId: String) = call {
        from("guests").select(Columns.list("name", "phone_e164")) { filter { eq("event_id", eventId) } }
            .decodeList<GuestPhoneRow>().mapNotNull { r -> r.phone_e164?.let { GuestPhone(r.name, it) } }
    }

    override suspend fun count(eventId: String) = call {
        from("guests").select(Columns.list("id")) { filter { eq("event_id", eventId) } }.decodeList<IdOnly>().size
    }

    override suspend fun add(eventId: String, guests: List<NewGuest>): AddResult {
        val c = client ?: return AddResult.Failed(AuthError.NotConfigured)
        if (guests.isEmpty()) return AddResult.Added(0)
        return try {
            c.postgrest.from("guests").insert(JsonArray(guests.map { it.toJson(eventId) })) { select(Columns.list("id")) }
            AddResult.Added(guests.size)
        } catch (e: RestException) {
            limitFrom(e) ?: AddResult.Failed(e.toAuthError())
        } catch (e: kotlin.coroutines.cancellation.CancellationException) {
            throw e
        } catch (e: Throwable) {
            AddResult.Failed(e.toAuthError())
        }
    }

    private suspend fun <T> call(block: suspend SupabaseClient.() -> T): AuthResult<T> {
        val c = client ?: return AuthResult.Failure(AuthError.NotConfigured)
        return runAuth { c.block() }
    }

    @Serializable private data class IdOnly(val id: String)
}

/** Rules loaded once from the bundled spec files (assets/spec, copied from /spec at build time). */
class GuestSpec(val excel: ExcelRules, val displayNames: DisplayNames) {
    val phones: Phones get() = excel.phones

    companion object {
        fun load(context: android.content.Context): GuestSpec {
            fun asset(name: String) = context.assets.open("spec/$name").bufferedReader().use { it.readText() }
            return GuestSpec(ExcelRules.fromJson(asset("excel.json"), asset("phones.json")), DisplayNames.fromJson(asset("invite.json")))
        }
    }
}
