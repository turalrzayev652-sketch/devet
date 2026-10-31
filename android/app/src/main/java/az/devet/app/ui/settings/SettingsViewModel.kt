package az.devet.app.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.AppLanguage
import az.devet.app.data.account.AccountRepository
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthRepository
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.AuthValidation
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SettingsState(
    val email: String = "",
    val savedName: String = "",
    val name: String = "",
    /** null = system language. */
    val language: String? = null,
    val loading: Boolean = true,
    val saving: Boolean = false,
    val saved: Boolean = false,
    val error: AuthError? = null,
    val deleteDialog: Boolean = false,
    val deleteConfirm: String = "",
    val deleting: Boolean = false,
    val deleteFailed: Boolean = false,
) {
    val canSaveName get() = AuthValidation.isName(name) && name.trim() != savedName && !saving

    /** The e-mail must be typed to confirm deletion (screens.md §12b). */
    val canDelete get() = email.isNotEmpty() && deleteConfirm.trim().equals(email, ignoreCase = true) && !deleting
}

/** Screen [12b] (spec/screens.md §12b). Sign-out and deletion end the session; AppViewModel then shows sign-in. */
class SettingsViewModel(
    private val account: AccountRepository,
    private val auth: AuthRepository,
    private val appLanguage: AppLanguage,
) : ViewModel() {
    private val _state = MutableStateFlow(SettingsState(email = auth.currentEmail.orEmpty(), language = appLanguage.selected))
    val state: StateFlow<SettingsState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val r = account.profile()) {
                is AuthResult.Ok -> _state.update {
                    val name = r.value.displayName.orEmpty()
                    it.copy(loading = false, savedName = name, name = name, email = r.value.email ?: it.email)
                }
                is AuthResult.Failure -> _state.update { it.copy(loading = false, error = r.error) }
            }
        }
    }

    fun onName(v: String) = _state.update { it.copy(name = v.take(AuthValidation.MAX_NAME), saved = false, error = null) }

    fun saveName() {
        val s = _state.value
        if (!s.canSaveName) return
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            when (val r = account.updateName(s.name.trim())) {
                is AuthResult.Ok -> _state.update { it.copy(saving = false, saved = true, savedName = s.name.trim(), name = s.name.trim()) }
                is AuthResult.Failure -> _state.update { it.copy(saving = false, error = r.error) }
            }
        }
    }

    /** Applies the language at once; profiles.ui_lang gets the language the UI now uses (it has no "system" value). */
    fun selectLanguage(lang: String?) {
        appLanguage.select(lang)
        _state.update { it.copy(language = lang) }
        val stored = lang ?: appLanguage.effective
        viewModelScope.launch { account.updateLanguage(stored) }
    }

    fun signOut() {
        viewModelScope.launch { auth.signOut() }
    }

    fun openDelete() = _state.update { it.copy(deleteDialog = true, deleteConfirm = "", deleteFailed = false) }
    fun closeDelete() = _state.update { it.copy(deleteDialog = false) }
    fun onDeleteConfirm(v: String) = _state.update { it.copy(deleteConfirm = v, deleteFailed = false) }

    fun deleteAccount() {
        if (!_state.value.canDelete) return
        _state.update { it.copy(deleting = true, deleteFailed = false) }
        viewModelScope.launch {
            when (val r = account.deleteAccount()) {
                is AuthResult.Ok -> {
                    auth.signOut()
                    _state.update { it.copy(deleting = false, deleteDialog = false) }
                }
                is AuthResult.Failure ->
                    if (r.error == AuthError.Unauthorized) auth.signOut()
                    else _state.update { it.copy(deleting = false, deleteFailed = true) }
            }
        }
    }
}
