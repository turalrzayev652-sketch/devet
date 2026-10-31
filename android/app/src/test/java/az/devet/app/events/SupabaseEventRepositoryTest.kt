package az.devet.app.events

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventType
import az.devet.app.data.events.MemberRole
import az.devet.app.data.events.SupabaseEventRepository
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/** Real supabase-kt Postgrest against canned PostgREST answers: request shape (api.md §2 [2], [3]) and RLS outcomes. */
class SupabaseEventRepositoryTest {
    private val requests = mutableListOf<HttpRequestData>()

    private fun repo(status: Int = 200, body: String = "[]"): SupabaseEventRepository {
        val client = createSupabaseClient("https://test.supabase.co", "anon-key") {
            httpEngine = MockEngine { req ->
                requests += req
                respond(body, HttpStatusCode.fromValue(status), headersOf(HttpHeaders.ContentType, "application/json"))
            }
            install(Auth) {
                sessionManager = MemorySessionManager()
                codeVerifierCache = MemoryCodeVerifierCache()
                autoLoadFromStorage = false
                alwaysAutoRefresh = false
                enableLifecycleCallbacks = false
            }
            install(Postgrest)
        }
        return SupabaseEventRepository(client)
    }

    private fun HttpRequestData.text() = (body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()

    @Test
    fun listParsesRoleAndStats() = runTest {
        val body = """[{"id":"e1","type":"engagement","title_names":"Aysel və Ramin","starts_at":"2027-07-12T14:00:00+00:00",
            "venue_name":"Ağ Saray","template_id":null,"status":"draft","templates":null,
            "event_members":[{"user_id":"other","role":"owner"}],
            "guests":[{"rsvp_status":"yes","rsvp_count":3,"sent_at":null,"opened_at":null},
                      {"rsvp_status":"yes","rsvp_count":2,"sent_at":null,"opened_at":null},
                      {"rsvp_status":"pending","rsvp_count":0,"sent_at":null,"opened_at":null},
                      {"rsvp_status":"no","rsvp_count":0,"sent_at":null,"opened_at":null}]}]"""
        val r = repo(body = body).list() as AuthResult.Ok
        val e = r.value.single()
        assertEquals(EventType.Engagement, e.type)
        assertEquals(Instant.parse("2027-07-12T14:00:00Z"), e.startsAt)
        assertEquals(4, e.guestCount)
        assertEquals("people coming", 5, e.comingPeople)
        assertEquals(1, e.noAnswer)
        assertEquals("no own membership row in the answer → owner by default", MemberRole.Owner, e.role)
        val url = requests.single().url
        assertTrue(url.encodedPath.endsWith("/rest/v1/events"))
        assertTrue(url.parameters["select"]!!.contains("guests(rsvp_status,rsvp_count"))
        assertTrue(url.parameters["order"]!!.startsWith("starts_at.asc"))
    }

    @Test
    fun createSendsColumnsWithoutCreatedBy() = runTest {
        val draft = EventDraft(
            EventType.Wedding, "Aysel və Ramin", "", Instant.parse("2027-07-12T14:00:00Z"), "Ağ Saray", "",
            "https://maps.google.com/?q=40.4093,49.8671", "az", false,
        )
        val r = repo(201, """[{"id":"new"}]""").create(draft)
        assertEquals(AuthResult.Ok("new"), r)
        val req = requests.single()
        assertEquals(HttpMethod.Post, req.method)
        val body = req.text()
        assertTrue(body, body.contains("\"starts_at\":\"2027-07-12T18:00+04:00\"") && body.contains("\"venue_lat\":40.4093"))
        assertFalse(body.contains("created_by"))
        assertTrue("return=representation", req.headers["Prefer"].orEmpty().contains("return=representation"))
    }

    @Test
    fun cohostDeleteGetsZeroRows() = runTest {
        assertEquals(AuthResult.Failure(AuthError.Forbidden), repo(200, "[]").delete("e1"))
        assertEquals(HttpMethod.Delete, requests.single().method)
        assertEquals("eq.e1", requests.single().url.parameters["id"])
    }

    @Test
    fun ownerDelete() = runTest {
        assertEquals(AuthResult.Ok(Unit), repo(200, """[{"id":"e1"}]""").delete("e1"))
    }

    @Test
    fun updateSendsOnlyChanges() = runTest {
        val before = EventDraft(EventType.Wedding, "A", "", Instant.parse("2027-07-12T14:00:00Z"), "Hall", "", "", "az", false)
        assertEquals(AuthResult.Ok(Unit), repo(200, """[{"id":"e1"}]""").update("e1", before, before.copy(showTablemates = true)))
        assertEquals("""{"show_tablemates":true}""", requests.single().text())
        requests.clear()
        assertEquals("no change → no request", AuthResult.Ok(Unit), repo().update("e1", before, before))
        assertTrue(requests.isEmpty())
    }

    @Test
    fun rlsInsertRefusal() = runTest {
        val body = """{"code":"42501","details":null,"hint":null,"message":"new row violates row-level security policy"}"""
        assertEquals(AuthResult.Failure(AuthError.Forbidden), repo(403, body).create(EventDraft(type = EventType.Wedding)))
    }
}
