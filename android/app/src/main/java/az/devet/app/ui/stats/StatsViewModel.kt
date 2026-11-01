package az.devet.app.ui.stats

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/// Screen [9]: Statistika (T49).
data class StatsState(
    val loading: Boolean = false,
    val error: AuthError? = null,
    val sent: Int = 0,
    val viewed: Int = 0,
    val coming: Int = 0,
    val declined: Int = 0,
    val noAnswer: Int = 0,
    val totalPeople: Int = 0,  // rsvp_count for coming guests
)

class StatsViewModel(
    private val eventId: String,
    private val repo: GuestListRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(StatsState())
    val state: StateFlow<StatsState> = _state

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)

            when (val result = repo.list(eventId)) {
                is AuthResult.Ok -> {
                    val guests = result.value
                    val stats = calculateStats(guests)
                    _state.value = _state.value.copy(
                        loading = false,
                        sent = stats.sent,
                        viewed = stats.viewed,
                        coming = stats.coming,
                        declined = stats.declined,
                        noAnswer = stats.noAnswer,
                        totalPeople = stats.totalPeople,
                    )
                }
                is AuthResult.Failure -> {
                    _state.value = _state.value.copy(
                        loading = false,
                        error = result.error
                    )
                }
            }
        }
    }

    private fun calculateStats(guests: List<Guest>): StatsData {
        var sent = 0
        var viewed = 0
        var coming = 0
        var declined = 0
        var noAnswer = 0
        var totalPeople = 0

        for (g in guests) {
            // Sent: sentAt dolu
            if (g.sentAt != null) sent++

            // Viewed: openedAt dolu
            if (g.openedAt != null) viewed++

            // RSVP status
            when (g.rsvpStatus) {
                "yes" -> {
                    coming++
                    totalPeople += g.rsvpCount
                }
                "no" -> declined++
                "pending" -> noAnswer++
            }
        }

        return StatsData(sent, viewed, coming, declined, noAnswer, totalPeople)
    }

    private data class StatsData(
        val sent: Int,
        val viewed: Int,
        val coming: Int,
        val declined: Int,
        val noAnswer: Int,
        val totalPeople: Int,
    )
}
