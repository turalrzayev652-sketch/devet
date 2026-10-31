package az.devet.app.ui.guests

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventRepository
import az.devet.app.data.guests.ExcelRules
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import az.devet.app.data.guests.GuestRules
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.GuestStatus
import az.devet.app.data.guests.NewGuest
import az.devet.app.data.guests.Side
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Filter chips of screen [6] (screens.md §6). */
enum class GuestFilter { All, Groom, Bride, Coming, Declined, NoAnswer, Unsent, NoTable }

fun GuestFilter.matches(g: Guest): Boolean = when (this) {
    GuestFilter.All -> true
    GuestFilter.Groom -> g.side == Side.Groom
    GuestFilter.Bride -> g.side == Side.Bride
    GuestFilter.Coming -> g.status == GuestStatus.Coming
    GuestFilter.Declined -> g.status == GuestStatus.Declined
    // Sent (seen or not) but not answered yet.
    GuestFilter.NoAnswer -> g.status == GuestStatus.Pending || g.status == GuestStatus.Viewed
    GuestFilter.Unsent -> g.status == GuestStatus.Unsent
    GuestFilter.NoTable -> g.tableNo.isNullOrBlank()
}

/** Search by name (case and Azerbaijani letters folded) or by phone digits (screens.md §6). */
fun searchMatches(g: Guest, query: String): Boolean {
    val q = query.trim()
    if (q.isEmpty()) return true
    if (ExcelRules.fold(g.name).contains(ExcelRules.fold(q))) return true
    // "050 123" must find +994 50 123…: the local trunk 0 is not part of E.164.
    val digits = q.filter(Char::isDigit).trimStart('0')
    return digits.length >= 3 && g.phoneE164?.filter(Char::isDigit)?.contains(digits) == true
}

/** Limit ring: ≥ 95 % gold with "N left", 100 % red with "limit reached" (screens.md §6). */
enum class LimitLevel { Normal, Near, Full }

fun limitLevel(count: Int, limit: Int?): LimitLevel = when {
    limit == null || limit <= 0 -> LimitLevel.Normal
    count >= limit -> LimitLevel.Full
    count * 100 >= limit * 95 -> LimitLevel.Near
    else -> LimitLevel.Normal
}

/** Edit sheet (§6.1): the same form as manual add. */
data class EditGuest(
    val guest: Guest,
    val form: GuestForm,
    val phoneIssue: PhoneIssue = PhoneIssue.None,
    val saving: Boolean = false,
    val attempted: Boolean = false,
) {
    val nameError get() = attempted && !GuestRules.nameOk(form.name)
    val canSave get() = GuestRules.nameOk(form.name) && phoneIssue == PhoneIssue.None && GuestRules.tableOk(form.table) && !saving
}

enum class GuestMessage { Saved, Deleted }

data class GuestListState(
    val guests: List<Guest> = emptyList(),
    val limit: Int? = null,
    val eventLang: String = "az",
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val error: AuthError? = null,
    val query: String = "",
    val filter: GuestFilter = GuestFilter.All,
    val selected: Set<String> = emptySet(),
    val editing: EditGuest? = null,
    /** Ids waiting for the delete confirmation. */
    val confirmDelete: List<String>? = null,
    val bulkTable: Boolean = false,
    val busy: Boolean = false,
    val actionError: AuthError? = null,
    val message: GuestMessage? = null,
) {
    val visible get() = guests.filter { filter.matches(it) && searchMatches(it, query) }
    fun count(f: GuestFilter) = guests.count(f::matches)
    val selecting get() = selected.isNotEmpty()
    val level get() = limitLevel(guests.size, limit)
}

/** Screen [6] Guests (spec/screens.md §6, api.md §2 [6]). Owner may delete; a co-host may not (§13). */
class GuestListViewModel(
    private val eventId: String,
    val isOwner: Boolean,
    private val repo: GuestListRepository,
    private val events: EventRepository,
    private val spec: GuestSpec,
) : ViewModel() {
    private val _state = MutableStateFlow(GuestListState())
    val state: StateFlow<GuestListState> = _state.asStateFlow()

    init {
        viewModelScope.launch { (events.get(eventId) as? AuthResult.Ok)?.let { r -> _state.update { it.copy(eventLang = r.value.defaultLang) } } }
        load()
    }

    fun load(refresh: Boolean = false) {
        _state.update { it.copy(loading = !refresh && it.guests.isEmpty(), refreshing = refresh, error = null) }
        viewModelScope.launch {
            val list = repo.list(eventId)
            val limit = (repo.limit(eventId) as? AuthResult.Ok)?.value
            _state.update {
                when (list) {
                    is AuthResult.Ok -> it.copy(guests = list.value, limit = limit ?: it.limit, loading = false, refreshing = false)
                    // Cached rows stay visible (screens.md §6).
                    is AuthResult.Failure -> it.copy(error = list.error, loading = false, refreshing = false)
                }
            }
        }
    }

    fun search(q: String) = _state.update { it.copy(query = q) }
    fun filter(f: GuestFilter) = _state.update { it.copy(filter = f) }
    fun messageShown() = _state.update { it.copy(message = null, actionError = null) }

    // --- selection (long press) ---
    fun toggle(id: String) = _state.update { s -> s.copy(selected = if (id in s.selected) s.selected - id else s.selected + id) }
    fun clearSelection() = _state.update { it.copy(selected = emptySet()) }

    // --- edit sheet ---
    fun open(g: Guest) = _state.update {
        it.copy(editing = EditGuest(g, GuestForm(g.salutation, g.name, g.withFamily, g.invitedCount, g.phoneE164.orEmpty(), g.side, g.tableNo.orEmpty(), g.lang)))
    }

    fun closeEdit() = _state.update { it.copy(editing = null) }

    fun edit(change: (GuestForm) -> GuestForm) = _state.update { s ->
        val e = s.editing ?: return@update s
        val f = change(e.form).let { f -> f.copy(name = f.name.take(GuestRules.MAX_NAME), count = f.count.coerceIn(1, GuestRules.MAX_COUNT), table = f.table.take(GuestRules.MAX_TABLE)) }
        s.copy(editing = e.copy(form = f, phoneIssue = phoneIssue(spec.phones, f.phone).second))
    }

    fun saveEdit() {
        val e = _state.value.editing ?: return
        if (!e.canSave) { _state.update { it.copy(editing = e.copy(attempted = true)) }; return }
        val f = e.form
        val after = NewGuest(f.name.trim(), f.salutation, f.withFamily, f.count, phoneIssue(spec.phones, f.phone).first, f.side, f.table.trim().ifEmpty { null }, f.lang)
        _state.update { it.copy(editing = e.copy(saving = true, attempted = true)) }
        viewModelScope.launch {
            when (val r = repo.update(e.guest.id, e.guest.fields, after)) {
                is AuthResult.Ok -> _state.update { s ->
                    val updated = e.guest.copy(
                        salutation = after.salutation, name = after.name, withFamily = after.withFamily, invitedCount = after.invitedCount,
                        phoneE164 = after.phoneE164, side = after.side, tableNo = after.tableNo, lang = after.lang,
                    )
                    s.copy(guests = s.guests.map { if (it.id == updated.id) updated else it }, editing = null, message = GuestMessage.Saved)
                }
                is AuthResult.Failure -> _state.update { it.copy(editing = e.copy(saving = false), actionError = r.error) }
            }
        }
    }

    // --- delete (owner) ---
    fun askDelete(ids: List<String>) { if (isOwner && ids.isNotEmpty()) _state.update { it.copy(confirmDelete = ids) } }
    fun cancelDelete() = _state.update { it.copy(confirmDelete = null) }

    fun confirmDelete() {
        val ids = _state.value.confirmDelete ?: return
        _state.update { it.copy(busy = true) }
        viewModelScope.launch {
            when (val r = repo.delete(ids)) {
                is AuthResult.Ok -> _state.update { s ->
                    s.copy(guests = s.guests.filterNot { it.id in ids }, selected = s.selected - ids.toSet(), confirmDelete = null, editing = null, busy = false, message = GuestMessage.Deleted)
                }
                is AuthResult.Failure -> _state.update { it.copy(confirmDelete = null, busy = false, actionError = r.error) }
            }
        }
    }

    // --- bulk table / side ---
    fun openBulkTable() = _state.update { it.copy(bulkTable = true) }
    fun closeBulkTable() = _state.update { it.copy(bulkTable = false) }

    fun bulkTable(table: String) = bulk("table_no", table.trim().take(GuestRules.MAX_TABLE).ifEmpty { null }) { g, v -> g.copy(tableNo = v) }
    fun bulkSide(side: Side) = bulk("side", side.key) { g, _ -> g.copy(side = side) }

    private fun bulk(column: String, value: String?, apply: (Guest, String?) -> Guest) {
        val ids = _state.value.selected.toList()
        if (ids.isEmpty()) return
        _state.update { it.copy(busy = true) }
        viewModelScope.launch {
            when (val r = repo.bulkUpdate(ids, column, value)) {
                is AuthResult.Ok -> _state.update { s ->
                    s.copy(guests = s.guests.map { if (it.id in ids) apply(it, value) else it }, selected = emptySet(), bulkTable = false, busy = false, message = GuestMessage.Saved)
                }
                is AuthResult.Failure -> _state.update { it.copy(busy = false, bulkTable = false, actionError = r.error) }
            }
        }
    }
}
