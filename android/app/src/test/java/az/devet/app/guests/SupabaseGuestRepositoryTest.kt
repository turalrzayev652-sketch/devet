package az.devet.app.guests

import az.devet.app.data.auth.AuthError
import az.devet.app.data.guests.AddResult
import az.devet.app.data.guests.NewGuest
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import az.devet.app.data.guests.SupabaseGuestRepository
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

/** Real supabase-kt against canned PostgREST answers: batch insert shape and the limit trigger (api.md §2 [7], §5). */
class SupabaseGuestRepositoryTest {
    private val requests = mutableListOf<HttpRequestData>()

    private fun repo(status: Int, body: String) = SupabaseGuestRepository(createSupabaseClient("https://test.supabase.co", "anon-key") {
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
    })

    private val two = listOf(
        NewGuest("Elçin", Salutation.Muellim, true, 4, "+994501234567", Side.Groom, "12"),
        NewGuest("Leyla"),
    )

    @Test
    fun batchInsertIsOneRequestWithoutServerColumns() = runTest {
        val r = repo(201, """[{"id":"a"},{"id":"b"}]""").add("e1", two)
        assertEquals(AddResult.Added(2), r)
        val req = requests.single()
        assertEquals(HttpMethod.Post, req.method)
        assertTrue(req.url.encodedPath.endsWith("/rest/v1/guests"))
        val body = (req.body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
        assertTrue(body, body.startsWith("[") && body.contains("\"event_id\":\"e1\"") && body.contains("\"salutation\":\"muellim\""))
        assertTrue(body, body.contains("\"phone_e164\":null") && body.contains("\"lang\":null"))
        assertFalse("code is server-only", body.contains("\"code\""))
        assertFalse("added_by defaults to auth.uid()", body.contains("added_by"))
    }

    @Test
    fun limitTriggerRefusesTheWholeBatch() = runTest {
        val body = """{"code":"P0001","details":"limit=100","hint":"purchase_required","message":"guest_limit_exceeded"}"""
        assertEquals(AddResult.LimitExceeded(100), repo(400, body).add("e1", two))
    }

    @Test
    fun rlsRefusal() = runTest {
        val body = """{"code":"42501","details":null,"hint":null,"message":"new row violates row-level security policy"}"""
        assertEquals(AddResult.Failed(AuthError.Forbidden), repo(403, body).add("e1", two))
    }
}
