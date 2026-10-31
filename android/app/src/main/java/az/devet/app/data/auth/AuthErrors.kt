package az.devet.app.data.auth

import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.plugins.HttpRequestTimeoutException
import java.io.IOException
import kotlin.coroutines.cancellation.CancellationException

/** An auth error the app detects itself (not thrown by the SDK). */
internal class AuthCodeException(val code: String) : Exception(code)

/** Runs a backend call and turns any failure into an [AuthError] (spec/api.md §0.2). */
internal suspend fun <T> runAuth(block: suspend () -> T): AuthResult<T> =
    try {
        AuthResult.Ok(block())
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        AuthResult.Failure(e.toAuthError())
    }

internal fun Throwable.toAuthError(): AuthError = when (this) {
    is AuthCodeException -> AuthError.fromCode(code)
    is AuthRestException -> AuthError.fromCode(error).let { if (it == AuthError.Unknown && statusCode == 401) AuthError.Unauthorized else it }
    is RestException -> if (statusCode == 401) AuthError.Unauthorized else AuthError.Unknown
    is HttpRequestException, is HttpRequestTimeoutException, is IOException -> AuthError.Network
    else -> if (cause != null && cause !== this) cause!!.toAuthError() else AuthError.Unknown
}
