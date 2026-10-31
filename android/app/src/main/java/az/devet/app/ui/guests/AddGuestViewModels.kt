package az.devet.app.ui.guests

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventRepository
import az.devet.app.data.guests.AddResult
import az.devet.app.data.guests.ExcelRules
import az.devet.app.data.guests.GuestPhone
import az.devet.app.data.guests.GuestRepository
import az.devet.app.data.guests.GuestRules
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.NewGuest
import az.devet.app.data.guests.Phones
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import az.devet.app.data.guests.XlsxReader
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.InputStream

// Screen [7] Add guests (spec/screens.md §7). Three tabs share the event context: existing phones (duplicate
// warning), the event's language (preview) and the server limit (api.md §5).

/** Limit sheet: the whole batch was refused; the tab keeps its data so it can be sent again after a purchase. */
data class LimitHit(val limit: Int?)

/** Phone field state under the input. */
enum class PhoneIssue { None, Invalid, NotMobile }

fun phoneIssue(phones: Phones, raw: String): Pair<String?, PhoneIssue> = when (val r = phones.normalize(raw)) {
    is Phones.Result.Ok -> r.e164 to PhoneIssue.None
    is Phones.Result.Error -> null to when (r.code) {
        "empty" -> PhoneIssue.None
        "not_mobile" -> PhoneIssue.NotMobile
        else -> PhoneIssue.Invalid
    }
}

// ---------------------------------------------------------------------------------------------------------------
// Shared event context
// ---------------------------------------------------------------------------------------------------------------

class GuestContext(
    private val eventId: String,
    private val guests: GuestRepository,
    private val events: EventRepository,
) {
    val existing = MutableStateFlow<List<GuestPhone>>(emptyList())
    val eventLang = MutableStateFlow("az")

    suspend fun load() {
        (guests.phones(eventId) as? AuthResult.Ok)?.let { existing.value = it.value }
        (events.get(eventId) as? AuthResult.Ok)?.let { eventLang.value = it.value.defaultLang }
    }

    fun ownerOf(e164: String?): String? = e164?.let { p -> existing.value.firstOrNull { it.phoneE164 == p }?.name }

    suspend fun add(list: List<NewGuest>): AddResult {
        val r = guests.add(eventId, list)
        if (r is AddResult.Added) existing.value = existing.value + list.mapNotNull { g -> g.phoneE164?.let { GuestPhone(g.name, it) } }
        return r
    }
}

// ---------------------------------------------------------------------------------------------------------------
// 7a Manual (and the form of §6.1)
// ---------------------------------------------------------------------------------------------------------------

data class GuestForm(
    val salutation: Salutation = Salutation.None,
    val name: String = "",
    val withFamily: Boolean = false,
    val count: Int = 1,
    val phone: String = "",
    val side: Side = Side.None,
    val table: String = "",
    /** null = event language. */
    val lang: String? = null,
)

data class ManualState(
    val form: GuestForm = GuestForm(),
    val eventLang: String = "az",
    val saving: Boolean = false,
    val attempted: Boolean = false,
    val error: AuthError? = null,
    val limit: LimitHit? = null,
    /** Display name of the guest just added ("… əlavə olundu"). */
    val added: String? = null,
    val closeAfterSave: Boolean = false,
    val done: Boolean = false,
    val duplicateOf: String? = null,
    val phoneIssue: PhoneIssue = PhoneIssue.None,
) {
    val nameError get() = attempted && !GuestRules.nameOk(form.name)
    val canSave get() = GuestRules.nameOk(form.name) && phoneIssue == PhoneIssue.None && GuestRules.tableOk(form.table) && !saving
}

class ManualGuestViewModel(private val ctx: GuestContext, private val spec: GuestSpec) : ViewModel() {
    private val _state = MutableStateFlow(ManualState())
    val state: StateFlow<ManualState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            ctx.load()
            _state.update { it.copy(eventLang = ctx.eventLang.value) }
        }
    }

    fun edit(change: (GuestForm) -> GuestForm) = _state.update {
        val form = change(it.form).let { f -> f.copy(name = f.name.take(GuestRules.MAX_NAME), count = f.count.coerceIn(1, GuestRules.MAX_COUNT), table = f.table.take(GuestRules.MAX_TABLE)) }
        val (e164, issue) = phoneIssue(spec.phones, form.phone)
        it.copy(form = form, phoneIssue = issue, duplicateOf = ctx.ownerOf(e164), error = null, added = null)
    }

    fun addedShown() = _state.update { it.copy(added = null) }
    fun limitShown() = _state.update { it.copy(limit = null) }

    /** "Yadda saxla və növbəti": the form clears; side, table and language stay (screens.md §7a). */
    fun save(andNext: Boolean) {
        val s = _state.value
        if (!s.canSave) { _state.value = s.copy(attempted = true); return }
        val f = s.form
        val guest = NewGuest(f.name.trim(), f.salutation, f.withFamily, f.count, phoneIssue(spec.phones, f.phone).first, f.side, f.table.trim().ifEmpty { null }, f.lang)
        _state.value = s.copy(saving = true, attempted = true)
        viewModelScope.launch {
            when (val r = ctx.add(listOf(guest))) {
                is AddResult.Added -> {
                    val shown = spec.displayNames.displayName(guest.name, guest.salutation, guest.withFamily, f.lang ?: s.eventLang)
                    _state.update {
                        it.copy(
                            saving = false, attempted = false, added = shown, done = !andNext,
                            form = if (andNext) GuestForm(side = f.side, table = f.table, lang = f.lang) else it.form,
                            duplicateOf = null, phoneIssue = PhoneIssue.None,
                        )
                    }
                }
                is AddResult.LimitExceeded -> _state.update { it.copy(saving = false, limit = LimitHit(r.limit)) }
                is AddResult.Failed -> _state.update { it.copy(saving = false, error = r.error) }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------
// 7b Contacts
// ---------------------------------------------------------------------------------------------------------------

data class PickedContact(
    val id: Long,
    val name: String,
    val phoneE164: String?,
    /** The picked number was not a usable mobile number → added without a phone (§15.7). */
    val noMobile: Boolean,
    val salutation: Salutation = Salutation.None,
    val count: Int = 1,
    val duplicateOf: String? = null,
)

data class ContactsState(
    val picked: List<PickedContact> = emptyList(),
    val saving: Boolean = false,
    val error: AuthError? = null,
    val limit: LimitHit? = null,
    val addedCount: Int? = null,
)

class ContactsViewModel(private val ctx: GuestContext, private val spec: GuestSpec) : ViewModel() {
    private val _state = MutableStateFlow(ContactsState())
    val state: StateFlow<ContactsState> = _state.asStateFlow()
    private var nextId = 0L

    init {
        viewModelScope.launch { ctx.load() }
    }

    fun picked(name: String, number: String?) {
        val (e164, _) = phoneIssue(spec.phones, number.orEmpty())
        val contact = PickedContact(nextId++, name.trim().take(GuestRules.MAX_NAME), e164, noMobile = e164 == null, duplicateOf = ctx.ownerOf(e164))
        _state.update { it.copy(picked = it.picked + contact, error = null) }
    }

    fun edit(id: Long, change: (PickedContact) -> PickedContact) =
        _state.update { s -> s.copy(picked = s.picked.map { if (it.id == id) change(it).let { c -> c.copy(count = c.count.coerceIn(1, GuestRules.MAX_COUNT)) } else it }) }

    fun remove(id: Long) = _state.update { s -> s.copy(picked = s.picked.filterNot { it.id == id }) }
    fun limitShown() = _state.update { it.copy(limit = null) }
    fun addedShown() = _state.update { it.copy(addedCount = null) }

    fun addAll() {
        val list = _state.value.picked.filter { GuestRules.nameOk(it.name) }
        if (list.isEmpty() || _state.value.saving) return
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val guests = list.map { NewGuest(it.name, it.salutation, false, it.count, it.phoneE164) }
            when (val r = ctx.add(guests)) {
                is AddResult.Added -> _state.update { it.copy(saving = false, picked = emptyList(), addedCount = r.count) }
                is AddResult.LimitExceeded -> _state.update { it.copy(saving = false, limit = LimitHit(r.limit)) }
                is AddResult.Failed -> _state.update { it.copy(saving = false, error = r.error) }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------
// 7c Excel
// ---------------------------------------------------------------------------------------------------------------

data class ErrorRow(val sheetRow: Int, val codes: List<String>)

sealed interface ExcelStep {
    data object Pick : ExcelStep
    data object Reading : ExcelStep
    /** `excel.file_error` or `excel.no_rows`. */
    data class FileError(val noRows: Boolean) : ExcelStep

    data class Mapping(
        val fileName: String,
        val headers: List<String>,
        val rows: List<List<ExcelRules.Cell>>,
        /** Column index → field (absent = ignored). */
        val columns: Map<Int, String>,
    ) : ExcelStep {
        val hasName get() = "name" in columns.values
    }

    data class Summary(
        val mapping: Mapping,
        val guests: List<NewGuest>,
        val errors: List<ErrorRow>,
        val duplicates: Int,
        val importing: Boolean = false,
    ) : ExcelStep
}

data class ExcelState(
    val step: ExcelStep = ExcelStep.Pick,
    val error: AuthError? = null,
    val limit: LimitHit? = null,
    val addedCount: Int? = null,
)

class ExcelImportViewModel(
    private val ctx: GuestContext,
    private val spec: GuestSpec,
    private val io: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {
    private val _state = MutableStateFlow(ExcelState())
    val state: StateFlow<ExcelState> = _state.asStateFlow()

    init {
        viewModelScope.launch { ctx.load() }
    }

    fun open(fileName: String, input: () -> InputStream) {
        _state.update { it.copy(step = ExcelStep.Reading, error = null) }
        viewModelScope.launch {
            val rows = withContext(io) { runCatching { input().use(XlsxReader::read) }.getOrNull() }
            _state.update { it.copy(step = mappingFor(fileName, rows)) }
        }
    }

    /** Header row → automatic column mapping (excel.json aliases); the user can change it. */
    internal fun mappingFor(fileName: String, rows: List<List<ExcelRules.Cell>>?): ExcelStep {
        if (rows == null) return ExcelStep.FileError(noRows = false)
        val headers = rows.firstOrNull()?.map(ExcelRules::asText).orEmpty()
        val data = rows.drop(1)
        if (data.none { r -> r.any { !ExcelRules.isEmpty(it) } }) return ExcelStep.FileError(noRows = true)
        // Without a name column the screen opens with what could be matched; the user picks the name column.
        val auto = spec.excel.mapHeadersPartial(headers)
        return ExcelStep.Mapping(fileName, headers, data, auto.entries.associate { (field, col) -> col to field })
    }

    fun setColumn(column: Int, field: String?) = _state.update { s ->
        val m = s.step as? ExcelStep.Mapping ?: return@update s
        val cols = m.columns.filterValues { it != field }.toMutableMap()
        if (field == null) cols.remove(column) else cols[column] = field
        s.copy(step = m.copy(columns = cols))
    }

    fun toSummary() = _state.update { s ->
        val m = s.step as? ExcelStep.Mapping ?: return@update s
        if (!m.hasName) return@update s
        val results = m.rows.map { row -> spec.excel.parseRow(m.columns.entries.associate { (col, field) -> field to (row.getOrNull(col) ?: ExcelRules.Cell.Empty) }) }
        val guests = mutableListOf<NewGuest>()
        val errors = mutableListOf<ErrorRow>()
        results.forEachIndexed { i, r ->
            when (r) {
                is ExcelRules.RowResult.Ok -> guests += r.guest
                // Row numbers as the family sees them in Excel (header is row 1).
                is ExcelRules.RowResult.Errors -> errors += ErrorRow(i + 2, r.codes)
                ExcelRules.RowResult.Skipped -> Unit
            }
        }
        val inFile = spec.excel.duplicateWarnings(results).size
        val inEvent = guests.count { ctx.ownerOf(it.phoneE164) != null }
        s.copy(step = if (guests.isEmpty() && errors.isEmpty()) ExcelStep.FileError(noRows = true) else ExcelStep.Summary(m, guests, errors, inFile + inEvent))
    }

    fun backToMapping() = _state.update { s -> (s.step as? ExcelStep.Summary)?.let { s.copy(step = it.mapping) } ?: s }
    fun restart() = _state.update { ExcelState() }
    fun limitShown() = _state.update { it.copy(limit = null) }
    fun addedShown() = _state.update { it.copy(addedCount = null) }

    /** One request for all rows; on a limit refusal the summary stays so the import can be repeated (§7). */
    fun import() {
        val summary = _state.value.step as? ExcelStep.Summary ?: return
        if (summary.guests.isEmpty() || summary.importing) return
        _state.update { it.copy(step = summary.copy(importing = true), error = null) }
        viewModelScope.launch {
            when (val r = ctx.add(summary.guests)) {
                is AddResult.Added -> _state.update { ExcelState(addedCount = r.count) }
                is AddResult.LimitExceeded -> _state.update { it.copy(step = summary, limit = LimitHit(r.limit)) }
                is AddResult.Failed -> _state.update { it.copy(step = summary, error = r.error) }
            }
        }
    }
}
