package az.devet.app.data.guests

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.runAuth
import az.devet.app.data.events.ForbiddenException
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Guest status shown as a pill (spec/design.md §2.2, api.md §0.3). */
enum class GuestStatus { Coming, Declined, Viewed, Pending, Unsent }

/** A guest row of screen [6] (api.md §1 Guest). */
data class Guest(
    val id: String,
    val code: String,
    val salutation: Salutation,
    val name: String,
    val withFamily: Boolean,
    val invitedCount: Int,
    val phoneE164: String?,
    val side: Side,
    val tableNo: String?,
    val lang: String?,
    val sentAt: String?,
    val openedAt: String?,
    val rsvpStatus: String,
    val rsvpCount: Int,
) {
    /** yes → coming, no → declined; pending with opened_at → viewed, with sent_at → pending, else unsent. */
    val status: GuestStatus
        get() = when {
            rsvpStatus == "yes" -> GuestStatus.Coming
            rsvpStatus == "no" -> GuestStatus.Declined
            openedAt != null -> GuestStatus.Viewed
            sentAt != null -> GuestStatus.Pending
            else -> GuestStatus.Unsent
        }

    /** The editable part (screens.md §6.1). */
    val fields get() = NewGuest(name, salutation, withFamily, invitedCount, phoneE164, side, tableNo, lang)
}

/** Columns the edit sheet may change (api.md §9 guests update), only those that differ. */
fun guestChanges(before: NewGuest, after: NewGuest): Map<String, JsonElement> {
    val b = columns(before)
    return columns(after).filter { (k, v) -> b[k] != v }
}

private fun columns(g: NewGuest): Map<String, JsonElement> {
    fun str(v: String?) = v?.let(::JsonPrimitive) ?: JsonNull
    return linkedMapOf(
        "salutation" to JsonPrimitive(g.salutation.key), "name" to JsonPrimitive(g.name.trim()),
        "with_family" to JsonPrimitive(g.withFamily), "invited_count" to JsonPrimitive(g.invitedCount),
        "phone_e164" to str(g.phoneE164), "side" to JsonPrimitive(g.side.key),
        "table_no" to str(g.tableNo?.trim()?.ifEmpty { null }), "lang" to str(g.lang),
    )
}

/** Screen [6] calls (api.md §2 [6]). */
interface GuestListRepository {
    suspend fun list(eventId: String): AuthResult<List<Guest>>

    /** `event_guest_limit(event_id)`; null when the user is not a member. */
    suspend fun limit(eventId: String): AuthResult<Int?>

    /** PATCH with the changed columns only; 0 rows → [AuthError.Forbidden]. */
    suspend fun update(id: String, before: NewGuest, after: NewGuest): AuthResult<Unit>

    /** Several guests at once: `table_no` or `side` (screens.md §6 bulk panel). */
    suspend fun bulkUpdate(ids: List<String>, column: String, value: String?): AuthResult<Unit>

    /** Owner only; a co-host gets 0 rows → [AuthError.Forbidden]. */
    suspend fun delete(ids: List<String>): AuthResult<Unit>
}

@Serializable
internal data class GuestRow(
    val id: String,
    val code: String = "",
    val salutation: String = "none",
    val name: String,
    @SerialName("with_family") val withFamily: Boolean = false,
    @SerialName("invited_count") val invitedCount: Int = 1,
    @SerialName("phone_e164") val phoneE164: String? = null,
    val side: String = "none",
    @SerialName("table_no") val tableNo: String? = null,
    val lang: String? = null,
    @SerialName("sent_at") val sentAt: String? = null,
    @SerialName("opened_at") val openedAt: String? = null,
    @SerialName("rsvp_status") val rsvpStatus: String = "pending",
    @SerialName("rsvp_count") val rsvpCount: Int = 0,
) {
    fun guest() = Guest(
        id, code, Salutation.of(salutation), name, withFamily, invitedCount, phoneE164, Side.of(side), tableNo, lang,
        sentAt, openedAt, rsvpStatus, rsvpCount,
    )
}

@Serializable private data class IdRow(val id: String)

class SupabaseGuestListRepository(private val client: SupabaseClient?) : GuestListRepository {

    override suspend fun list(eventId: String) = call {
        from("guests").select { filter { eq("event_id", eventId) }; order("name", Order.ASCENDING) }.decodeList<GuestRow>().map { it.guest() }
    }

    override suspend fun limit(eventId: String) = call {
        postgrest.rpc("event_guest_limit", buildJsonObject { put("p_event_id", eventId) }).data.trim().toIntOrNull()
    }

    override suspend fun update(id: String, before: NewGuest, after: NewGuest) = call {
        val changes = guestChanges(before, after)
        if (changes.isNotEmpty()) {
            val rows = from("guests").update(JsonObject(changes)) { filter { eq("id", id) }; select(Columns.list("id")) }.decodeList<IdRow>()
            if (rows.isEmpty()) throw ForbiddenException()
        }
    }

    override suspend fun bulkUpdate(ids: List<String>, column: String, value: String?) = call {
        require(column == "table_no" || column == "side")
        if (ids.isNotEmpty()) {
            val body = JsonObject(mapOf(column to (value?.let(::JsonPrimitive) ?: JsonNull)))
            val rows = from("guests").update(body) { filter { isIn("id", ids) }; select(Columns.list("id")) }.decodeList<IdRow>()
            if (rows.isEmpty()) throw ForbiddenException()
        }
    }

    override suspend fun delete(ids: List<String>) = call {
        if (ids.isNotEmpty()) {
            val rows = from("guests").delete { filter { isIn("id", ids) }; select(Columns.list("id")) }.decodeList<IdRow>()
            if (rows.isEmpty()) throw ForbiddenException()
        }
    }

    private suspend fun <T> call(block: suspend SupabaseClient.() -> T): AuthResult<T> {
        val c = client ?: return AuthResult.Failure(AuthError.NotConfigured)
        return runAuth { c.block() }
    }
}
