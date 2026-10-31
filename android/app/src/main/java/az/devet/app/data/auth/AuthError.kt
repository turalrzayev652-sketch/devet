package az.devet.app.data.auth

/** Auth error categories from spec/api.md §0.2 and §2 [1]. iOS uses the same set (parity rule). */
enum class AuthError {
    InvalidCredentials,
    EmailNotConfirmed,
    UserAlreadyExists,
    WeakPassword,
    RateLimited,
    LinkInvalid,
    Unauthorized,
    /** RLS refused the change (PostgREST 42501 or 0 rows updated/deleted). */
    Forbidden,
    Network,
    /** Build has no Supabase settings (local.properties); only happens in development. */
    NotConfigured,
    Unknown;

    companion object {
        /** Maps a Supabase Auth `error_code` (GoTrue) to a category. */
        fun fromCode(code: String?): AuthError = when (code) {
            "invalid_credentials" -> InvalidCredentials
            "email_not_confirmed" -> EmailNotConfirmed
            "user_already_exists", "email_exists" -> UserAlreadyExists
            "weak_password" -> WeakPassword
            "over_email_send_rate_limit", "over_request_rate_limit" -> RateLimited
            "otp_expired", "flow_state_expired", "flow_state_not_found", "bad_code_verifier", "access_denied" -> LinkInvalid
            "session_not_found", "session_expired", "refresh_token_not_found", "no_authorization" -> Unauthorized
            else -> Unknown
        }
    }
}

sealed interface AuthResult<out T> {
    data class Ok<T>(val value: T) : AuthResult<T>
    data class Failure(val error: AuthError) : AuthResult<Nothing>
}
