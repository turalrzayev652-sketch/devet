package az.devet.app.data.auth

import java.net.URI
import java.net.URLDecoder

/**
 * Links from Supabase Auth e-mails (custom scheme, decision 2026-10-31):
 * - `az.devet.app://auth/callback?code=…` — sign-up confirmation;
 * - `az.devet.app://auth/reset-password?code=…` — password recovery.
 * PKCE: the code is exchanged for a session. Errors arrive as `error_code` in the query or fragment.
 */
data class AuthDeepLink(val kind: Kind, val code: String?, val errorCode: String?) {
    enum class Kind { Confirm, Recovery }

    companion object {
        const val SCHEME = "az.devet.app"
        const val HOST = "auth"
        const val CONFIRM_URL = "$SCHEME://$HOST/callback"
        const val RECOVERY_URL = "$SCHEME://$HOST/reset-password"

        fun parse(link: String?): AuthDeepLink? {
            val uri = runCatching { URI(link ?: return null) }.getOrNull() ?: return null
            if (uri.scheme != SCHEME || uri.host != HOST) return null
            val kind = when (uri.path?.trimEnd('/')) {
                "/callback" -> Kind.Confirm
                "/reset-password" -> Kind.Recovery
                else -> return null
            }
            val params = params(uri.rawQuery) + params(uri.rawFragment)
            val error = params["error_code"] ?: params["error"]
            return AuthDeepLink(kind, params["code"]?.takeIf { it.isNotBlank() }, error)
        }

        private fun params(raw: String?): Map<String, String> =
            raw.orEmpty().split('&').filter { '=' in it }.associate {
                val (k, v) = it.split('=', limit = 2)
                URLDecoder.decode(k, "UTF-8") to URLDecoder.decode(v, "UTF-8")
            }
    }
}
