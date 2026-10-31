package az.devet.app.data.auth

import kotlinx.coroutines.flow.StateFlow

enum class SessionState { Loading, SignedIn, SignedOut }

/** Supabase Auth calls for screen [1] (spec/api.md §2 [1]). The SDK keeps and refreshes the session itself. */
interface AuthRepository {
    val session: StateFlow<SessionState>
    val currentEmail: String?

    suspend fun signIn(email: String, password: String): AuthResult<Unit>

    /** Ok(true) — confirmation e-mail sent; Ok(false) — signed in straight away (confirmations off). */
    suspend fun signUp(name: String, email: String, password: String): AuthResult<Boolean>

    suspend fun resendConfirmation(email: String): AuthResult<Unit>

    /** Always reports success for unknown e-mails too — account existence is not revealed (screens.md §1). */
    suspend fun sendPasswordReset(email: String): AuthResult<Unit>

    /** PKCE code from an e-mail link → session. */
    suspend fun exchangeCode(code: String): AuthResult<Unit>

    suspend fun updatePassword(password: String): AuthResult<Unit>

    suspend fun signOut()
}
