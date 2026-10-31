package az.devet.app.data.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.OtpType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** [client] is null when the build has no Supabase settings: the app starts signed out and every call fails softly. */
class SupabaseAuthRepository(private val client: SupabaseClient?, scope: CoroutineScope) : AuthRepository {

    override val session: StateFlow<SessionState> =
        client?.auth?.sessionStatus
            ?.map {
                when (it) {
                    is SessionStatus.Authenticated -> SessionState.SignedIn
                    is SessionStatus.Initializing -> SessionState.Loading
                    // A failed refresh keeps the stored session; the SDK retries, so the user stays in the app.
                    is SessionStatus.RefreshFailure -> SessionState.SignedIn
                    is SessionStatus.NotAuthenticated -> SessionState.SignedOut
                }
            }
            ?.stateIn(scope, SharingStarted.Eagerly, SessionState.Loading)
            ?: MutableStateFlow(SessionState.SignedOut)

    override val currentEmail: String? get() = client?.auth?.currentUserOrNull()?.email

    override suspend fun signIn(email: String, password: String) = call {
        auth.signInWith(Email) {
            this.email = email.trim()
            this.password = password
        }
    }

    override suspend fun signUp(name: String, email: String, password: String) = call {
        val user = auth.signUpWith(Email, redirectUrl = AuthDeepLink.CONFIRM_URL) {
            this.email = email.trim()
            this.password = password
            data = buildJsonObject { put("display_name", name.trim()) }
        }
        // With confirmations on, GoTrue answers an existing e-mail with an obfuscated user without identities.
        if (user != null && user.identities?.isEmpty() == true) throw AuthCodeException("user_already_exists")
        auth.currentSessionOrNull() == null
    }

    override suspend fun resendConfirmation(email: String) = call {
        auth.resendEmail(OtpType.Email.SIGNUP, email.trim())
    }

    override suspend fun sendPasswordReset(email: String) = call {
        auth.resetPasswordForEmail(email.trim(), redirectUrl = AuthDeepLink.RECOVERY_URL)
    }

    override suspend fun exchangeCode(code: String) = call {
        auth.exchangeCodeForSession(code)
        Unit
    }

    override suspend fun updatePassword(password: String) = call {
        auth.updateUser { this.password = password }
        Unit
    }

    override suspend fun signOut() {
        call { auth.signOut() }
    }

    private suspend fun <T> call(block: suspend SupabaseClient.() -> T): AuthResult<T> {
        val c = client ?: return AuthResult.Failure(AuthError.NotConfigured)
        return runAuth { c.block() }
    }
}
