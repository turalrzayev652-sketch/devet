package az.devet.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthDeepLink
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthRepository
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.SessionState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** One-off messages shown at the app level (after e-mail links). */
enum class AppMessage { LinkInvalid, Network, PasswordUpdated }

/** Session and e-mail links: decides whether the user sees sign-in, the app or the new-password screen. */
class AppViewModel(private val auth: AuthRepository) : ViewModel() {
    val session: StateFlow<SessionState> = auth.session

    private val _recovery = MutableStateFlow(false)

    /** True while the user must set a new password after a recovery link (the link already signed them in). */
    val recovery: StateFlow<Boolean> = _recovery.asStateFlow()

    private val _message = MutableStateFlow<AppMessage?>(null)
    val message: StateFlow<AppMessage?> = _message.asStateFlow()

    fun handleLink(uri: String?) {
        val link = AuthDeepLink.parse(uri) ?: return
        val code = link.code
        if (link.errorCode != null || code == null) {
            _message.value = AppMessage.LinkInvalid
            return
        }
        // Set before the exchange: the session appears first and must not open the app instead of the new-password screen.
        if (link.kind == AuthDeepLink.Kind.Recovery) _recovery.value = true
        viewModelScope.launch {
            val result = auth.exchangeCode(code)
            if (result is AuthResult.Failure) {
                _recovery.value = false
                _message.value = if (result.error == AuthError.Network) AppMessage.Network else AppMessage.LinkInvalid
            }
        }
    }

    fun passwordUpdated() {
        _recovery.value = false
        _message.value = AppMessage.PasswordUpdated
    }

    fun messageShown() {
        _message.value = null
    }
}
