package az.devet.app.ui.send

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventRepository
import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import az.devet.app.data.guests.PreviewImage
import az.devet.app.data.guests.PreviewImageGenerator
import az.devet.app.data.guests.PreviewParams
import az.devet.app.data.guests.StorageRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/// Screen 8a: Göndərmədən əvvəl adları yoxlayın.
/// Hər qonaq üçün preview şəkli yaradır və yükləyir (T47).
data class PreviewWarning(
    val type: String,  // "no_phone", "empty_name"
    val count: Int
)

data class PreviewListState(
    val loading: Boolean = false,
    val guests: List<Guest> = emptyList(),
    val previews: Map<String, PreviewImage> = emptyMap(),
    val warnings: List<PreviewWarning> = emptyList(),
    val uploadProgress: String = "",  // "140 / 212"
    val uploadError: AuthError? = null,
    val allReady: Boolean = false
)

class PreviewListViewModel(
    private val eventId: String,
    private val repo: GuestListRepository,
    private val events: EventRepository,
    private val storage: StorageRepository,
    private val displayNames: DisplayNames,
) : ViewModel() {
    private val generator = PreviewImageGenerator()

    private val _state = MutableStateFlow(PreviewListState())
    val state: StateFlow<PreviewListState> = _state

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true)
            when (val result = repo.list(eventId)) {
                is AuthResult.Ok -> {
                    val guests = result.value.filter { !it.phoneE164.isNullOrBlank() }  // Only those to send
                    _state.value = _state.value.copy(guests = guests, loading = false)
                    generateAndUploadPreviews(guests)
                }
                is AuthResult.Failure -> {
                    _state.value = _state.value.copy(loading = false, uploadError = result.error)
                }
            }
        }
    }

    private fun generateAndUploadPreviews(guests: List<Guest>) {
        viewModelScope.launch {
            val event = when (val result = events.get(eventId)) {
                is AuthResult.Ok -> result.value
                is AuthResult.Failure -> {
                    _state.value = _state.value.copy(uploadError = result.error)
                    return@launch
                }
            }

            val previews = mutableMapOf<String, PreviewImage>()
            val warnings = mutableListOf<PreviewWarning>()

            for ((idx, guest) in guests.withIndex()) {
                _state.value = _state.value.copy(uploadProgress = "${idx} / ${guests.size}")

                // Validasiya xəbərdarlıkları
                if (guest.phoneE164.isNullOrBlank()) {
                    warnings.add(PreviewWarning("no_phone", 1))
                }
                if (guest.name.isBlank()) {
                    warnings.add(PreviewWarning("empty_name", 1))
                }

                // Preview şəkli yarat
                val displayName = displayNames.format(guest.salutation, guest.name, guest.withFamily)
                val params = PreviewParams(
                    displayName = displayName,
                    code = guest.code,
                    lang = guest.lang ?: event.defaultLang,
                    templateBgColor = (event.customization as? Map<String, Any>)?.get("colors")
                        ?.let { (it as? Map<String, String>)?.get("--dv-color-bg") }
                )

                try {
                    val preview = generator.generate(params)
                    previews[guest.code] = preview

                    // Storage-ə yüklə
                    when (val uploadResult = storage.uploadPreviewImage(preview.bytes, guest.code, eventId)) {
                        is AuthResult.Ok -> {}  // Success
                        is AuthResult.Failure -> throw Exception("Upload failed: ${uploadResult.error}")
                    }
                } catch (e: Exception) {
                    _state.value = _state.value.copy(
                        uploadError = AuthError.Network,
                        uploadProgress = "${idx} / ${guests.size} — xəta"
                    )
                    return@launch
                }
            }

            // Xəbərdarlıkları birləştir
            val uniqueWarnings = warnings.groupBy { it.type }.map { (type, items) ->
                PreviewWarning(type, items.size)
            }

            _state.value = _state.value.copy(
                previews = previews,
                warnings = uniqueWarnings,
                uploadProgress = "${guests.size} / ${guests.size}",
                uploadError = null,
                allReady = true
            )
        }
    }
}
