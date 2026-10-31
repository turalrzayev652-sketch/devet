package az.devet.app.auth

import az.devet.app.data.auth.AuthDeepLink
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.SupabaseAuthRepository
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.createSupabaseClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/** The real supabase-kt client against canned GoTrue answers: checks the SDK error → [AuthError] mapping and request shape. */
class SupabaseAuthRepositoryTest {
    private val requests = mutableListOf<HttpRequestData>()

    private fun TestScope.repo(handler: suspend MockRequestHandleScope.(HttpRequestData) -> io.ktor.client.request.HttpResponseData): SupabaseAuthRepository {
        val client = createSupabaseClient("https://test.supabase.co", "anon-key") {
            httpEngine = MockEngine { req -> requests += req; handler(req) }
            install(Auth) {
                flowType = FlowType.PKCE
                scheme = AuthDeepLink.SCHEME
                host = AuthDeepLink.HOST
                sessionManager = MemorySessionManager()
                codeVerifierCache = MemoryCodeVerifierCache()
                autoLoadFromStorage = false
                alwaysAutoRefresh = false
                enableLifecycleCallbacks = false
            }
        }
        return SupabaseAuthRepository(client, backgroundScope)
    }

    private fun MockRequestHandleScope.json(status: Int, body: String) =
        respond(body, HttpStatusCode.fromValue(status), headersOf(HttpHeaders.ContentType, "application/json"))

    private fun error(status: Int, code: String) = """{"code":$status,"error_code":"$code","msg":"$code"}"""

    private fun user(identities: String) = """{"id":"11111111-1111-1111-1111-111111111111","aud":"authenticated","role":"authenticated",
        "email":"aysel@example.com","app_metadata":{},"user_metadata":{"display_name":"Aysel"},"identities":$identities,
        "created_at":"2026-10-31T10:00:00Z","updated_at":"2026-10-31T10:00:00Z"}"""

    @Test
    fun wrongPassword() = runTest {
        val r = repo { json(400, error(400, "invalid_credentials")) }.signIn("aysel@example.com", "nope")
        assertEquals(AuthResult.Failure(AuthError.InvalidCredentials), r)
        assertTrue(requests.single().url.encodedPath.endsWith("/auth/v1/token"))
    }

    @Test
    fun unconfirmedEmail() = runTest {
        val r = repo { json(400, error(400, "email_not_confirmed")) }.signIn("aysel@example.com", "secret1")
        assertEquals(AuthResult.Failure(AuthError.EmailNotConfirmed), r)
    }

    @Test
    fun networkFailure() = runTest {
        val r = repo { throw IOException("offline") }.signIn("aysel@example.com", "secret1")
        assertEquals(AuthResult.Failure(AuthError.Network), r)
    }

    @Test
    fun signUpSendsNameAndRedirect() = runTest {
        val r = repo { json(200, user("""[{"identity_id":"x","id":"x","user_id":"x","provider":"email","identity_data":{}}]""")) }
            .signUp(" Aysel ", " aysel@example.com ", "secret1")
        assertEquals("confirmation needed (no session)", AuthResult.Ok(true), r)
        val req = requests.single()
        assertTrue(req.url.encodedPath.endsWith("/auth/v1/signup"))
        assertEquals(AuthDeepLink.CONFIRM_URL, req.url.parameters["redirect_to"])
        val body = String((req.body as io.ktor.http.content.OutgoingContent.ByteArrayContent).bytes())
        assertTrue(body, body.contains("\"display_name\":\"Aysel\"") && body.contains("\"email\":\"aysel@example.com\""))
    }

    @Test
    fun signUpExistingEmailWithConfirmationsOn() = runTest {
        val r = repo { json(200, user("[]")) }.signUp("Aysel", "aysel@example.com", "secret1")
        assertEquals(AuthResult.Failure(AuthError.UserAlreadyExists), r)
    }

    @Test
    fun signUpExistingEmailWithConfirmationsOff() = runTest {
        val r = repo { json(422, error(422, "user_already_exists")) }.signUp("Aysel", "aysel@example.com", "secret1")
        assertEquals(AuthResult.Failure(AuthError.UserAlreadyExists), r)
    }

    @Test
    fun weakPassword() = runTest {
        val body = """{"code":422,"error_code":"weak_password","msg":"weak","weak_password":{"reasons":["length"]}}"""
        val r = repo { json(422, body) }.signUp("Aysel", "aysel@example.com", "123456")
        assertEquals(AuthResult.Failure(AuthError.WeakPassword), r)
    }

    @Test
    fun resetUsesRecoveryLink() = runTest {
        val r = repo { json(200, "{}") }.sendPasswordReset("aysel@example.com")
        assertEquals(AuthResult.Ok(Unit), r)
        val req = requests.single()
        assertTrue(req.url.encodedPath.endsWith("/auth/v1/recover"))
        assertEquals(AuthDeepLink.RECOVERY_URL, req.url.parameters["redirect_to"])
    }

    @Test
    fun rateLimitedResend() = runTest {
        val r = repo { json(429, error(429, "over_email_send_rate_limit")) }.resendConfirmation("aysel@example.com")
        assertEquals(AuthResult.Failure(AuthError.RateLimited), r)
    }

    @Test
    fun withoutSettingsEverythingFailsSoftly() = runTest {
        val r = SupabaseAuthRepository(null, backgroundScope).signIn("a@b.c", "secret1")
        assertEquals(AuthResult.Failure(AuthError.NotConfigured), r)
    }
}
