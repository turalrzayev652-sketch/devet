package az.devet.app.data.events

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.runAuth
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.time.Instant
import java.time.OffsetDateTime

/** Screens [2] and [3] (spec/api.md §2 [2], [3]). RLS limits every call to the user's own events. */
interface EventRepository {
    suspend fun list(): AuthResult<List<EventSummary>>
    suspend fun get(id: String): AuthResult<EventDraft>

    /** Returns the new event id (the creator becomes owner by trigger). */
    suspend fun create(draft: EventDraft): AuthResult<String>

    /** PATCH with only the changed columns; nothing to send → Ok without a request. */
    suspend fun update(id: String, before: EventDraft, after: EventDraft): AuthResult<Unit>

    /** Owner only: RLS returns 0 rows for a co-host → [AuthError.Forbidden]. */
    suspend fun delete(id: String): AuthResult<Unit>
}

@Serializable
internal data class EventRow(
    val id: String,
    val type: String,
    @SerialName("title_names") val titleNames: String,
    @SerialName("host_names") val hostNames: String? = null,
    @SerialName("starts_at") val startsAt: String,
    @SerialName("venue_name") val venueName: String,
    @SerialName("venue_address") val venueAddress: String? = null,
    @SerialName("maps_url") val mapsUrl: String? = null,
    @SerialName("default_lang") val defaultLang: String = "az",
    @SerialName("show_tablemates") val showTablemates: Boolean = false,
    val templates: TemplateRef? = null,
    @SerialName("event_members") val members: List<MemberRow> = emptyList(),
    val guests: List<GuestStat> = emptyList(),
) {
    @Serializable internal data class TemplateRef(@SerialName("thumbnail_url") val thumbnailUrl: String? = null)
    @Serializable internal data class MemberRow(@SerialName("user_id") val userId: String, val role: String)
    @Serializable internal data class GuestStat(
        @SerialName("rsvp_status") val rsvpStatus: String = "pending",
        @SerialName("rsvp_count") val rsvpCount: Int = 0,
    )

    fun summary(userId: String?) = EventSummary(
        id = id,
        type = EventType.of(type),
        titleNames = titleNames,
        startsAt = parseInstant(startsAt),
        venueName = venueName,
        thumbnailUrl = templates?.thumbnailUrl,
        role = if (members.firstOrNull { it.userId == userId }?.role == "cohost") MemberRole.Cohost else MemberRole.Owner,
        guestCount = guests.size,
        comingPeople = guests.filter { it.rsvpStatus == "yes" }.sumOf { it.rsvpCount },
        noAnswer = guests.count { it.rsvpStatus == "pending" },
    )

    fun draft() = EventDraft(
        type = EventType.of(type), titleNames = titleNames, hostNames = hostNames.orEmpty(), startsAt = parseInstant(startsAt),
        venueName = venueName, venueAddress = venueAddress.orEmpty(), mapsUrl = mapsUrl.orEmpty(),
        defaultLang = defaultLang, showTablemates = showTablemates,
    )
}

@Serializable internal data class IdRow(val id: String)

internal fun parseInstant(s: String): Instant = OffsetDateTime.parse(s.replace(' ', 'T')).toInstant()

internal fun Map<String, Any?>.toJson() = JsonObject(mapValues { (_, v) ->
    when (v) {
        null -> JsonNull
        is String -> JsonPrimitive(v)
        is Number -> JsonPrimitive(v)
        is Boolean -> JsonPrimitive(v)
        else -> error("unsupported column value $v")
    } as JsonElement
})

class SupabaseEventRepository(private val client: SupabaseClient?) : EventRepository {

    override suspend fun list() = call {
        val rows = from("events").select(Columns.raw(LIST_COLUMNS)) { order("starts_at", Order.ASCENDING) }.decodeList<EventRow>()
        val uid = auth.currentUserOrNull()?.id
        rows.map { it.summary(uid) }
    }

    override suspend fun get(id: String) = call {
        from("events").select(Columns.raw(EDIT_COLUMNS)) { filter { eq("id", id) } }.decodeSingle<EventRow>().draft()
    }

    override suspend fun create(draft: EventDraft) = call {
        from("events").insert(EventRules.columns(draft).toJson()) { select(Columns.list("id")) }.decodeSingle<IdRow>().id
    }

    override suspend fun update(id: String, before: EventDraft, after: EventDraft) = call {
        val changes = EventRules.changes(before, after)
        if (changes.isNotEmpty()) {
            val rows = from("events").update(changes.toJson()) {
                filter { eq("id", id) }
                select(Columns.list("id"))
            }.decodeList<IdRow>()
            if (rows.isEmpty()) throw ForbiddenException()
        }
    }

    override suspend fun delete(id: String) = call {
        val rows = from("events").delete {
            filter { eq("id", id) }
            select(Columns.list("id"))
        }.decodeList<IdRow>()
        if (rows.isEmpty()) throw ForbiddenException()
    }

    private suspend fun <T> call(block: suspend SupabaseClient.() -> T): AuthResult<T> {
        val c = client ?: return AuthResult.Failure(AuthError.NotConfigured)
        return runAuth { c.block() }
    }

    private companion object {
        const val LIST_COLUMNS = "id,type,title_names,starts_at,venue_name,template_id,status," +
            "templates(thumbnail_url),event_members(user_id,role),guests(rsvp_status,rsvp_count,sent_at,opened_at)"
        const val EDIT_COLUMNS = "id,type,title_names,host_names,starts_at,venue_name,venue_address,maps_url,default_lang,show_tablemates"
    }
}

/** RLS hid the row: the user may not change or delete it (api.md §0.2 `forbidden`). */
internal class ForbiddenException : Exception("forbidden")
