package az.devet.app.auth

import az.devet.app.data.auth.AuthDeepLink
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthValidation
import az.devet.app.data.auth.SessionState
import az.devet.app.ui.navigation.Route
import az.devet.app.ui.navigation.rootFor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Rules shared with iOS (screens.md §1, api.md §2 [1]). */
class AuthRulesTest {
    @Test
    fun emailFormat() {
        listOf("a@b.c", "aysel.mammadova@example.com", "  x@y.az ").forEach { assertTrue(it, AuthValidation.isEmail(it)) }
        listOf("", "a@b", "@b.c", "a b@c.d", "a@b c.d", "ab.c").forEach { assertFalse(it, AuthValidation.isEmail(it)) }
    }

    @Test
    fun passwordAtLeastSix() {
        assertFalse(AuthValidation.isPassword("12345"))
        assertTrue(AuthValidation.isPassword("123456"))
    }

    @Test
    fun registerNeedsEveryField() {
        assertTrue(AuthValidation.canRegister("Aysel", "a@b.c", "secret1", "secret1", true))
        assertFalse(AuthValidation.canRegister(" ", "a@b.c", "secret1", "secret1", true))
        assertFalse(AuthValidation.canRegister("Aysel", "a@b", "secret1", "secret1", true))
        assertFalse(AuthValidation.canRegister("Aysel", "a@b.c", "12345", "12345", true))
        assertFalse(AuthValidation.canRegister("Aysel", "a@b.c", "secret1", "secret2", true))
        assertFalse(AuthValidation.canRegister("Aysel", "a@b.c", "secret1", "secret1", false))
        assertFalse(AuthValidation.canRegister("x".repeat(81), "a@b.c", "secret1", "secret1", true))
    }

    @Test
    fun signInNeedsEmailAndAnyPassword() {
        assertTrue(AuthValidation.canSignIn("a@b.c", "1"))
        assertFalse(AuthValidation.canSignIn("a@b.c", ""))
    }

    @Test
    fun errorCodesFromSupabaseAuth() {
        assertEquals(AuthError.InvalidCredentials, AuthError.fromCode("invalid_credentials"))
        assertEquals(AuthError.EmailNotConfirmed, AuthError.fromCode("email_not_confirmed"))
        assertEquals(AuthError.UserAlreadyExists, AuthError.fromCode("user_already_exists"))
        assertEquals(AuthError.WeakPassword, AuthError.fromCode("weak_password"))
        assertEquals(AuthError.RateLimited, AuthError.fromCode("over_email_send_rate_limit"))
        assertEquals(AuthError.LinkInvalid, AuthError.fromCode("otp_expired"))
        assertEquals(AuthError.Unknown, AuthError.fromCode("something_new"))
        assertEquals(AuthError.Unknown, AuthError.fromCode(null))
    }

    @Test
    fun deepLinks() {
        assertEquals(
            AuthDeepLink(AuthDeepLink.Kind.Recovery, "abc-123", null),
            AuthDeepLink.parse("az.devet.app://auth/reset-password?code=abc-123"),
        )
        assertEquals(
            AuthDeepLink(AuthDeepLink.Kind.Confirm, "c0de", null),
            AuthDeepLink.parse("az.devet.app://auth/callback?code=c0de"),
        )
        // Expired link: GoTrue puts the error in the fragment.
        val expired = AuthDeepLink.parse("az.devet.app://auth/callback#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid")
        assertEquals("otp_expired", expired?.errorCode)
        assertNull(expired?.code)
        assertNull(AuthDeepLink.parse("https://example.com/auth/callback?code=x"))
        assertNull(AuthDeepLink.parse("az.devet.app://auth/other?code=x"))
        assertNull(AuthDeepLink.parse(null))
        assertNull(AuthDeepLink.parse("not a uri %%"))
    }

    @Test
    fun rootScreenFollowsSession() {
        assertEquals(Route.Splash, rootFor(SessionState.Loading, false))
        assertEquals(Route.SignIn, rootFor(SessionState.SignedOut, false))
        assertEquals(Route.Events, rootFor(SessionState.SignedIn, false))
        assertEquals(Route.NewPassword, rootFor(SessionState.SignedIn, true))
        // Recovery flag set before the code exchange finishes: stay on sign-in until the session arrives.
        assertEquals(Route.SignIn, rootFor(SessionState.SignedOut, true))
    }
}
