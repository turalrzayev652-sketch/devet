package az.devet.app.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthRepository
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.AuthValidation
import az.devet.app.data.network.Connectivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// Successful sign-in / sign-up changes the session; AppViewModel then opens the app. These view models only
// hold form state, loading and errors. Screen flow and rules: spec/screens.md §1.

data class SignInState(
    val email: String = "",
    val password: String = "",
    val loading: Boolean = false,
    val error: AuthError? = null,
    /** Set when the account exists but the e-mail is not confirmed → confirmation screen. */
    val unconfirmedEmail: String? = null,
) {
    val canSubmit get() = AuthValidation.canSignIn(email, password) && !loading
}

class SignInViewModel(private val auth: AuthRepository, connectivity: Connectivity) : ViewModel() {
    val online: StateFlow<Boolean> = connectivity.isOnline
    private val _state = MutableStateFlow(SignInState())
    val state: StateFlow<SignInState> = _state.asStateFlow()

    fun onEmail(v: String) = _state.update { it.copy(email = v, error = null) }
    fun onPassword(v: String) = _state.update { it.copy(password = v, error = null) }
    fun confirmationShown() = _state.update { it.copy(unconfirmedEmail = null) }

    fun submit() {
        val s = _state.value
        if (!s.canSubmit) return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val r = auth.signIn(s.email, s.password)) {
                is AuthResult.Ok -> _state.update { it.copy(loading = false, password = "") }
                is AuthResult.Failure ->
                    if (r.error == AuthError.EmailNotConfirmed) _state.update { it.copy(loading = false, unconfirmedEmail = s.email.trim()) }
                    else _state.update { it.copy(loading = false, error = r.error) }
            }
        }
    }
}

data class RegisterState(
    val name: String = "",
    val email: String = "",
    val password: String = "",
    val repeat: String = "",
    val termsAccepted: Boolean = false,
    val loading: Boolean = false,
    val error: AuthError? = null,
    /** Set after sign-up when a confirmation e-mail was sent. */
    val confirmationSentTo: String? = null,
) {
    val canSubmit get() = AuthValidation.canRegister(name, email, password, repeat, termsAccepted) && !loading
    val passwordMismatch get() = repeat.isNotEmpty() && repeat.length >= password.length && repeat != password

    /** Everything else is valid — the only missing step is the terms checkbox. */
    val termsMissing get() = !termsAccepted && AuthValidation.canRegister(name, email, password, repeat, true)
}

class RegisterViewModel(private val auth: AuthRepository, connectivity: Connectivity) : ViewModel() {
    val online: StateFlow<Boolean> = connectivity.isOnline
    private val _state = MutableStateFlow(RegisterState())
    val state: StateFlow<RegisterState> = _state.asStateFlow()

    fun onName(v: String) = _state.update { it.copy(name = v.take(AuthValidation.MAX_NAME), error = null) }
    fun onEmail(v: String) = _state.update { it.copy(email = v, error = null) }
    fun onPassword(v: String) = _state.update { it.copy(password = v, error = null) }
    fun onRepeat(v: String) = _state.update { it.copy(repeat = v, error = null) }
    fun onTerms(v: Boolean) = _state.update { it.copy(termsAccepted = v) }
    fun confirmationShown() = _state.update { it.copy(confirmationSentTo = null) }

    fun submit() {
        val s = _state.value
        if (!s.canSubmit) return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val r = auth.signUp(s.name, s.email, s.password)) {
                is AuthResult.Ok -> _state.update { it.copy(loading = false, confirmationSentTo = if (r.value) s.email.trim() else null) }
                is AuthResult.Failure -> _state.update { it.copy(loading = false, error = r.error) }
            }
        }
    }
}

data class ResendState(val sending: Boolean = false, val sent: Boolean = false, val error: AuthError? = null)

class ConfirmEmailViewModel(private val auth: AuthRepository) : ViewModel() {
    private val _state = MutableStateFlow(ResendState())
    val state: StateFlow<ResendState> = _state.asStateFlow()

    fun resend(email: String) {
        if (_state.value.sending) return
        _state.value = ResendState(sending = true)
        viewModelScope.launch {
            _state.value = when (val r = auth.resendConfirmation(email)) {
                is AuthResult.Ok -> ResendState(sent = true)
                is AuthResult.Failure -> ResendState(error = r.error)
            }
        }
    }
}

data class ResetState(val email: String = "", val loading: Boolean = false, val error: AuthError? = null, val sent: Boolean = false) {
    val canSubmit get() = AuthValidation.isEmail(email) && !loading
}

class ResetPasswordViewModel(private val auth: AuthRepository, connectivity: Connectivity) : ViewModel() {
    val online: StateFlow<Boolean> = connectivity.isOnline
    private val _state = MutableStateFlow(ResetState())
    val state: StateFlow<ResetState> = _state.asStateFlow()

    fun onEmail(v: String) = _state.update { it.copy(email = v, error = null) }
    fun sentShown() = _state.update { it.copy(sent = false) }

    fun submit() {
        val s = _state.value
        if (!s.canSubmit) return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val r = auth.sendPasswordReset(s.email)) {
                is AuthResult.Ok -> _state.update { it.copy(loading = false, sent = true) }
                // Only transport errors are shown; anything else still says "check your e-mail" (no account probing).
                is AuthResult.Failure ->
                    if (r.error == AuthError.Network || r.error == AuthError.RateLimited || r.error == AuthError.NotConfigured)
                        _state.update { it.copy(loading = false, error = r.error) }
                    else _state.update { it.copy(loading = false, sent = true) }
            }
        }
    }
}

data class NewPasswordState(
    val password: String = "",
    val repeat: String = "",
    val loading: Boolean = false,
    val error: AuthError? = null,
    val done: Boolean = false,
) {
    val canSubmit get() = AuthValidation.canSetPassword(password, repeat) && !loading
    val passwordMismatch get() = repeat.isNotEmpty() && repeat.length >= password.length && repeat != password
}

class NewPasswordViewModel(private val auth: AuthRepository) : ViewModel() {
    private val _state = MutableStateFlow(NewPasswordState())
    val state: StateFlow<NewPasswordState> = _state.asStateFlow()

    fun onPassword(v: String) = _state.update { it.copy(password = v, error = null) }
    fun onRepeat(v: String) = _state.update { it.copy(repeat = v, error = null) }

    fun submit() {
        val s = _state.value
        if (!s.canSubmit) return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val r = auth.updatePassword(s.password)) {
                is AuthResult.Ok -> _state.update { it.copy(loading = false, done = true) }
                is AuthResult.Failure -> _state.update { it.copy(loading = false, error = r.error) }
            }
        }
    }
}
