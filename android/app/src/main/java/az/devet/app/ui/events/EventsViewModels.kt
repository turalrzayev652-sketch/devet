package az.devet.app.ui.events

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.AppLanguage
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.ArchiveStore
import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventRepository
import az.devet.app.data.events.EventRules
import az.devet.app.data.events.EventSummary
import az.devet.app.data.events.MapsLink
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant

// ---------------------------------------------------------------------------------------------------------------
// [2] Events list (spec/screens.md §2)
// ---------------------------------------------------------------------------------------------------------------

enum class EventsMessage { Deleted }

data class EventsState(
    val events: List<EventSummary> = emptyList(),
    val manuallyArchived: Set<String> = emptySet(),
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    /** Load error; cached cards stay visible (screens.md §2). */
    val error: AuthError? = null,
    val showArchive: Boolean = false,
    val deleteTarget: EventSummary? = null,
    val deleting: Boolean = false,
    val actionError: AuthError? = null,
    val message: EventsMessage? = null,
    val now: Instant = Instant.now(),
) {
    fun isArchived(e: EventSummary) = e.id in manuallyArchived || EventRules.isArchivedByDate(e.startsAt, now)

    /** Upcoming first (soonest on top), then events of the last 7 days (latest first). */
    val active: List<EventSummary>
        get() = events.filterNot(::isArchived).let { list ->
            val (upcoming, past) = list.partition { !it.startsAt.isBefore(now) }
            upcoming.sortedBy { it.startsAt } + past.sortedByDescending { it.startsAt }
        }

    val archived: List<EventSummary> get() = events.filter(::isArchived).sortedByDescending { it.startsAt }

    /** Manual archiving can be undone; date-based archiving cannot. */
    fun canUnarchive(e: EventSummary) = e.id in manuallyArchived && !EventRules.isArchivedByDate(e.startsAt, now)
}

class EventsViewModel(
    private val repo: EventRepository,
    private val archive: ArchiveStore,
    private val clock: () -> Instant = Instant::now,
) : ViewModel() {
    private val _state = MutableStateFlow(EventsState(manuallyArchived = archive.archived(), now = clock()))
    val state: StateFlow<EventsState> = _state.asStateFlow()

    init {
        load()
    }

    fun load(refresh: Boolean = false) {
        _state.update { it.copy(loading = !refresh && it.events.isEmpty(), refreshing = refresh, error = null) }
        viewModelScope.launch {
            val r = repo.list()
            _state.update {
                when (r) {
                    is AuthResult.Ok -> it.copy(events = r.value, loading = false, refreshing = false, now = clock())
                    is AuthResult.Failure -> it.copy(error = r.error, loading = false, refreshing = false, now = clock())
                }
            }
        }
    }

    fun showArchive(show: Boolean) = _state.update { it.copy(showArchive = show) }

    fun setArchived(e: EventSummary, archived: Boolean) {
        archive.setArchived(e.id, archived)
        _state.update { it.copy(manuallyArchived = archive.archived()) }
    }

    fun askDelete(e: EventSummary) = _state.update { it.copy(deleteTarget = e, actionError = null) }
    fun cancelDelete() = _state.update { it.copy(deleteTarget = null) }
    fun messageShown() = _state.update { it.copy(message = null, actionError = null) }

    fun confirmDelete() {
        val target = _state.value.deleteTarget ?: return
        _state.update { it.copy(deleting = true) }
        viewModelScope.launch {
            when (val r = repo.delete(target.id)) {
                is AuthResult.Ok -> {
                    archive.setArchived(target.id, false)
                    _state.update {
                        it.copy(
                            events = it.events.filterNot { e -> e.id == target.id }, deleting = false, deleteTarget = null,
                            message = EventsMessage.Deleted, manuallyArchived = archive.archived(),
                        )
                    }
                }
                is AuthResult.Failure -> _state.update { it.copy(deleting = false, deleteTarget = null, actionError = r.error) }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------
// [3] Create (6 steps) — spec/screens.md §3
// ---------------------------------------------------------------------------------------------------------------

/** What the map field shows under it (step 4). */
enum class MapStatus { None, CoordsFound, NoCoords, Invalid }

fun mapStatus(link: String): MapStatus = when (val r = MapsLink.parse(link)) {
    is MapsLink.Result.Error -> if (r.code == "empty") MapStatus.None else MapStatus.Invalid
    is MapsLink.Result.Ok -> if (r.lat != null) MapStatus.CoordsFound else MapStatus.NoCoords
}

data class CreateState(
    val draft: EventDraft,
    val step: Int = 1,
    val creating: Boolean = false,
    val error: AuthError? = null,
    val createdId: String? = null,
    val now: Instant = Instant.now(),
) {
    val canNext get() = EventRules.stepValid(step, draft, now) && !creating
    val isLast get() = step == STEPS

    companion object {
        const val STEPS = 6
    }
}

class CreateEventViewModel(
    private val repo: EventRepository,
    language: AppLanguage,
    private val clock: () -> Instant = Instant::now,
) : ViewModel() {
    private val _state = MutableStateFlow(CreateState(EventDraft(defaultLang = language.effective), now = clock()))
    val state: StateFlow<CreateState> = _state.asStateFlow()

    fun edit(change: (EventDraft) -> EventDraft) = _state.update { it.copy(draft = change(it.draft), error = null, now = clock()) }

    fun next() {
        val s = _state.value.copy(now = clock())
        if (!s.canNext) return
        if (s.isLast) create() else _state.value = s.copy(step = s.step + 1)
    }

    fun back() = _state.update { if (it.step > 1) it.copy(step = it.step - 1) else it }

    private fun create() {
        _state.update { it.copy(creating = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.create(_state.value.draft)) {
                is AuthResult.Ok -> _state.update { it.copy(creating = false, createdId = r.value) }
                // The form stays as it was (screens.md §3: "forma məlumatı saxlanır").
                is AuthResult.Failure -> _state.update { it.copy(creating = false, error = r.error) }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------
// [3] Edit — one page with sections
// ---------------------------------------------------------------------------------------------------------------

data class EditState(
    val original: EventDraft? = null,
    val draft: EventDraft = EventDraft(),
    val loading: Boolean = true,
    val saving: Boolean = false,
    val error: AuthError? = null,
    val saved: Boolean = false,
    val now: Instant = Instant.now(),
) {
    val changed get() = original != null && EventRules.changes(original, draft).isNotEmpty()

    /** A past date cannot be chosen (§15.4); an unchanged date of a past event does not block other edits. */
    val dateOk get() = draft.startsAt == original?.startsAt || EventRules.dateOk(draft.startsAt, now)

    val valid get() = draft.type != null && EventRules.titleOk(draft.titleNames) && EventRules.hostsOk(draft.hostNames) &&
        dateOk && EventRules.venueOk(draft.venueName) && EventRules.mapsOk(draft.mapsUrl)

    val canSave get() = changed && valid && !saving
}

class EditEventViewModel(
    private val repo: EventRepository,
    private val eventId: String,
    private val clock: () -> Instant = Instant::now,
) : ViewModel() {
    private val _state = MutableStateFlow(EditState(now = clock()))
    val state: StateFlow<EditState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.get(eventId)) {
                is AuthResult.Ok -> _state.update { it.copy(original = r.value, draft = r.value, loading = false) }
                is AuthResult.Failure -> _state.update { it.copy(loading = false, error = r.error) }
            }
        }
    }

    fun edit(change: (EventDraft) -> EventDraft) = _state.update { it.copy(draft = change(it.draft), saved = false, error = null, now = clock()) }

    fun save() {
        val s = _state.value.copy(now = clock())
        val original = s.original ?: return
        if (!s.canSave) return
        _state.value = s.copy(saving = true, error = null)
        viewModelScope.launch {
            when (val r = repo.update(eventId, original, s.draft)) {
                // Last write wins when both families edit at once (screens.md §15.8).
                is AuthResult.Ok -> _state.update { it.copy(saving = false, saved = true, original = s.draft) }
                is AuthResult.Failure -> _state.update { it.copy(saving = false, error = r.error) }
            }
        }
    }
}
