package az.devet.app.events

import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventRules
import az.devet.app.data.events.EventType
import az.devet.app.data.events.MapsLink
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Instant

class EventRulesTest {
    private val root = File(System.getProperty("devet.repoRoot") ?: error("devet.repoRoot not set"))
    private val now = Instant.parse("2027-01-10T10:00:00Z")

    /** Every case of spec/test-vectors/maps.json (shared with iOS and the JS reference). */
    @Test
    fun mapsVectors() {
        val cases = Json.parseToJsonElement(File(root, "spec/test-vectors/maps.json").readText()).jsonObject["cases"]!!.jsonArray
        assertTrue(cases.size >= 20)
        for (case in cases.map { it.jsonObject }) {
            val input = case["input"]!!.jsonPrimitive.content
            val result = MapsLink.parse(input)
            val error = case["error"]?.jsonPrimitive?.content
            if (error != null) {
                assertEquals(input, MapsLink.Result.Error(error), result)
                continue
            }
            val ok = result as? MapsLink.Result.Ok ?: error("expected Ok for $input, got $result")
            val expected = case["expected"]
            if (expected == null || expected is JsonNull) {
                assertNull(input, ok.lat)
            } else {
                expected as JsonObject
                assertEquals(input, expected["lat"]!!.jsonPrimitive.double, ok.lat!!, 1e-9)
                assertEquals(input, expected["lng"]!!.jsonPrimitive.double, ok.lng!!, 1e-9)
            }
        }
    }

    private val full = EventDraft(
        type = EventType.Wedding, titleNames = " Aysel və Ramin ", hostNames = "", startsAt = Instant.parse("2027-07-12T14:00:00Z"),
        venueName = "Ağ Saray", venueAddress = "", mapsUrl = "https://maps.google.com/?q=40.4093,49.8671", defaultLang = "az",
    )

    @Test
    fun stepRules() {
        assertFalse(EventRules.stepValid(1, EventDraft(), now))
        assertTrue(EventRules.stepValid(1, full, now))
        assertFalse(EventRules.stepValid(2, full.copy(titleNames = "  "), now))
        assertFalse(EventRules.stepValid(2, full.copy(titleNames = "x".repeat(81)), now))
        assertFalse(EventRules.stepValid(2, full.copy(hostNames = "x".repeat(121)), now))
        assertTrue(EventRules.stepValid(2, full, now))
        assertFalse("past date", EventRules.stepValid(3, full.copy(startsAt = now.minusSeconds(60)), now))
        assertFalse(EventRules.stepValid(3, full.copy(startsAt = null), now))
        assertTrue(EventRules.stepValid(3, full, now))
        assertFalse(EventRules.stepValid(4, full.copy(venueName = ""), now))
        assertFalse("bad link", EventRules.stepValid(4, full.copy(mapsUrl = "maps.google.com/?q=1,2"), now))
        assertTrue("short link is fine", EventRules.stepValid(4, full.copy(mapsUrl = "https://maps.app.goo.gl/x"), now))
        assertTrue(EventRules.stepValid(4, full.copy(mapsUrl = ""), now))
    }

    @Test
    fun insertColumns() {
        val cols = EventRules.columns(full)
        assertEquals("wedding", cols["type"])
        assertEquals("Aysel və Ramin", cols["title_names"])
        assertNull(cols["host_names"])
        assertEquals("Baku time with offset", "2027-07-12T18:00+04:00", cols["starts_at"])
        assertEquals(40.4093, cols["venue_lat"])
        assertEquals(49.8671, cols["venue_lng"])
        assertFalse("created_by is never sent (api.md §2 [3])", "created_by" in cols)
        assertFalse("status is server-side", "status" in cols)
    }

    @Test
    fun changedLinkClearsOldCoordinates() {
        val changes = EventRules.changes(full, full.copy(mapsUrl = "https://maps.app.goo.gl/x"))
        assertEquals(setOf("maps_url", "venue_lat", "venue_lng"), changes.keys)
        assertNull(changes["venue_lat"])
        assertTrue(EventRules.changes(full, full).isEmpty())
        assertEquals(setOf("show_tablemates"), EventRules.changes(full, full.copy(showTablemates = true)).keys)
    }

    @Test
    fun archiveAfterSevenDays() {
        assertFalse(EventRules.isArchivedByDate(now.minusSeconds(6 * 86400), now))
        assertTrue(EventRules.isArchivedByDate(now.minusSeconds(8 * 86400), now))
    }
}
