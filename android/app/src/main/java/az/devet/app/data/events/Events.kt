package az.devet.app.data.events

import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/** `event_type` enum (PRODUCT.md §4). */
enum class EventType(val key: String) {
    Wedding("wedding"), Engagement("engagement"), Henna("henna"), Birthday("birthday"), Jubilee("jubilee");

    companion object {
        fun of(key: String) = entries.firstOrNull { it.key == key } ?: Wedding
    }
}

enum class MemberRole { Owner, Cohost }

/** Event card on screen [2] (spec/api.md §2 [2]). */
data class EventSummary(
    val id: String,
    val type: EventType,
    val titleNames: String,
    val startsAt: Instant,
    val venueName: String,
    val thumbnailUrl: String?,
    val role: MemberRole,
    val guestCount: Int,
    /** People coming: sum of rsvp_count where rsvp_status = yes. */
    val comingPeople: Int,
    /** Guests with rsvp_status = pending. */
    val noAnswer: Int,
)

/** Form state of screen [3] — also the editable fields of an existing event. */
data class EventDraft(
    val type: EventType? = null,
    val titleNames: String = "",
    val hostNames: String = "",
    val startsAt: Instant? = null,
    val venueName: String = "",
    val venueAddress: String = "",
    val mapsUrl: String = "",
    val defaultLang: String = "az",
    val showTablemates: Boolean = false,
)

object EventRules {
    const val MAX_TITLE = 80
    const val MAX_HOSTS = 120
    const val MAX_VENUE = 120

    /** Events are shown and entered in Baku time (spec/api.md §0.1). */
    val ZONE: ZoneId = ZoneId.of("Asia/Baku")

    /** An event moves to "Arxiv" 7 days after it starts (screens.md §15.2). */
    val ARCHIVE_AFTER: Duration = Duration.ofDays(7)

    fun isArchivedByDate(startsAt: Instant, now: Instant) = startsAt.plus(ARCHIVE_AFTER).isBefore(now)

    fun titleOk(v: String) = v.trim().length in 1..MAX_TITLE
    fun hostsOk(v: String) = v.trim().length <= MAX_HOSTS
    fun venueOk(v: String) = v.trim().length in 1..MAX_VENUE
    fun dateOk(v: Instant?, now: Instant) = v != null && v.isAfter(now)
    fun mapsOk(v: String) = v.isBlank() || MapsLink.parse(v) is MapsLink.Result.Ok

    /** Wizard steps 1–6 (screens.md §3). Step 5 and 6 always pass. */
    fun stepValid(step: Int, d: EventDraft, now: Instant): Boolean = when (step) {
        1 -> d.type != null
        2 -> titleOk(d.titleNames) && hostsOk(d.hostNames)
        3 -> dateOk(d.startsAt, now)
        4 -> venueOk(d.venueName) && mapsOk(d.mapsUrl)
        else -> true
    }

    /**
     * Columns for insert / update (api.md §9). Coordinates come from the map link; a link without readable
     * coordinates stores null so an old pin never outlives a changed link.
     */
    fun columns(d: EventDraft): Map<String, Any?> {
        val maps = d.mapsUrl.trim()
        val coords = (MapsLink.parse(maps) as? MapsLink.Result.Ok)
        return linkedMapOf(
            "type" to d.type?.key,
            "title_names" to d.titleNames.trim(),
            "host_names" to d.hostNames.trim().ifEmpty { null },
            "starts_at" to d.startsAt?.atZone(ZONE)?.toOffsetDateTime()?.toString(),
            "venue_name" to d.venueName.trim(),
            "venue_address" to d.venueAddress.trim().ifEmpty { null },
            "maps_url" to maps.ifEmpty { null },
            "venue_lat" to coords?.lat,
            "venue_lng" to coords?.lng,
            "default_lang" to d.defaultLang,
            "show_tablemates" to d.showTablemates,
        )
    }

    /** Only the changed columns for PATCH (api.md §2 [3]). */
    fun changes(before: EventDraft, after: EventDraft): Map<String, Any?> {
        val a = columns(before)
        return columns(after).filter { (k, v) -> a[k] != v }
    }
}
