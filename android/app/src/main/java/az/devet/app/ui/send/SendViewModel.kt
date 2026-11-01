package az.devet.app.ui.send

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventRepository
import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.net.URLEncoder
import java.time.Instant

/// Screen 8b: Qonaq-qonaq WhatsApp axını (T48).
data class SendState(
    val loading: Boolean = false,
    val guests: List<Guest> = emptyList(),
    val currentIndex: Int = 0,
    val sentCount: Int = 0,
    val dailyWarning: Boolean = false,
    val allDone: Boolean = false,
    val error: AuthError? = null,
)

class SendViewModel(
    private val eventId: String,
    private val repo: GuestListRepository,
    private val events: EventRepository,
    private val displayNames: DisplayNames,
) : ViewModel() {

    private val _state = MutableStateFlow(SendState())
    val state: StateFlow<SendState> = _state

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)

            // Load event for types and default lang
            val eventResult = events.get(eventId)
            if (eventResult !is AuthResult.Ok) {
                _state.value = _state.value.copy(
                    loading = false,
                    error = (eventResult as? AuthResult.Failure)?.error
                )
                return@launch
            }
            val event = eventResult.value

            // Load unsent guests (those with phones)
            val guestResult = repo.list(eventId)
            if (guestResult !is AuthResult.Ok) {
                _state.value = _state.value.copy(
                    loading = false,
                    error = (guestResult as? AuthResult.Failure)?.error
                )
                return@launch
            }

            val unsent = guestResult.value.filter {
                it.sentAt == null && !it.phoneE164.isNullOrBlank()
            }

            _state.value = _state.value.copy(
                loading = false,
                guests = unsent,
                currentIndex = 0,
                allDone = unsent.isEmpty(),
            )
        }
    }

    fun currentGuest(): Guest? {
        val state = _state.value
        return if (state.currentIndex < state.guests.size) state.guests[state.currentIndex] else null
    }

    /// WhatsApp mesajı qonağın dilində (spec/i18n/app.json wa_message.<event_type>)
    fun buildWaMessage(guest: Guest, eventTitle: String, eventType: String, lang: String, baseUrl: String): String {
        val displayName = displayNames.format(guest.salutation, guest.name, guest.withFamily)
        val link = "$baseUrl/i/${guest.code}"

        // Templates from spec/i18n/app.json
        val template = when (eventType) {
            "wedding" -> when (lang) {
                "ru" -> "Здравствуйте, {display_name}! Приглашаем вас на свадьбу: {title_names}. Приглашение: {link}"
                "en" -> "Dear {display_name}, you are invited to the wedding of {title_names}. Invitation: {link}"
                "tr" -> "Sayın {display_name}, düğüne davetlisiniz: {title_names}. Davetiye: {link}"
                else -> "Hörmətli {display_name}! {title_names} toyuna dəvətlisiniz. Dəvətnamə: {link}"
            }
            "engagement" -> when (lang) {
                "ru" -> "Здравствуйте, {display_name}! Приглашаем вас на помолвку: {title_names}. Приглашение: {link}"
                "en" -> "Dear {display_name}, you are invited to the engagement of {title_names}. Invitation: {link}"
                "tr" -> "Sayın {display_name}, nişana davetlisiniz: {title_names}. Davetiye: {link}"
                else -> "Hörmətli {display_name}! {title_names} nişanına dəvətlisiniz. Dəvətnamə: {link}"
            }
            "henna" -> when (lang) {
                "ru" -> "Здравствуйте, {display_name}! Приглашаем вас на вечер хны: {title_names}. Приглашение: {link}"
                "en" -> "Dear {display_name}, you are invited to the henna night of {title_names}. Invitation: {link}"
                "tr" -> "Sayın {display_name}, kına gecesine davetlisiniz: {title_names}. Davetiye: {link}"
                else -> "Hörmətli {display_name}! {title_names} xınayaxdısına dəvətlisiniz. Dəvətnamə: {link}"
            }
            "birthday" -> when (lang) {
                "ru" -> "Здравствуйте, {display_name}! Приглашаем вас на день рождения: {title_names}. Приглашение: {link}"
                "en" -> "Dear {display_name}, you are invited to the birthday of {title_names}. Invitation: {link}"
                "tr" -> "Sayın {display_name}, doğum gününe davetlisiniz: {title_names}. Davetiye: {link}"
                else -> "Hörmətli {display_name}! {title_names} ad gününə dəvətlisiniz. Dəvətnamə: {link}"
            }
            "jubilee" -> when (lang) {
                "ru" -> "Здравствуйте, {display_name}! Приглашаем вас на юбилей: {title_names}. Приглашение: {link}"
                "en" -> "Dear {display_name}, you are invited to the jubilee of {title_names}. Invitation: {link}"
                "tr" -> "Sayın {display_name}, jübileye davetlisiniz: {title_names}. Davetiye: {link}"
                else -> "Hörmətli {display_name}! {title_names} yubileyinə dəvətlisiniz. Dəvətnamə: {link}"
            }
            else -> "Hörmətli {display_name}! {title_names} dəvətlisiniz. Dəvətnamə: {link}"
        }

        return template
            .replace("{display_name}", displayName)
            .replace("{title_names}", eventTitle)
            .replace("{link}", link)
    }

    /// wa.me linki (E.164 phones without +, URL-encoded message)
    fun buildWaLink(phone: String, message: String): String {
        val phoneClean = phone.removePrefix("+")
        val encoded = URLEncoder.encode(message, "UTF-8")
        return "https://wa.me/$phoneClean?text=$encoded"
    }

    /// "Bəli, növbəti" — sent_at yazılması
    fun confirmSent(guest: Guest) {
        viewModelScope.launch {
            when (repo.markSent(guest.id)) {
                is AuthResult.Ok -> {
                    val newIndex = _state.value.currentIndex + 1
                    val newSentCount = _state.value.sentCount + 1
                    _state.value = _state.value.copy(
                        currentIndex = newIndex,
                        sentCount = newSentCount,
                        allDone = newIndex >= _state.value.guests.size
                    )
                }
                is AuthResult.Failure -> {
                    // Retry logic here
                }
            }
        }
    }

    /// "Xeyr, yenidən" — göndərilməmiş qalır, sonrakı
    fun skip() {
        val newIndex = _state.value.currentIndex + 1
        _state.value = _state.value.copy(
            currentIndex = newIndex,
            allDone = newIndex >= _state.value.guests.size
        )
    }

    /// Geri basma — göndərilməmişlərdən davam etmə
    fun goBack() {
        // Navigator handles this; state keeps track internally
    }
}
