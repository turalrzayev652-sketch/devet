package az.devet.app.ui.guests

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.data.guests.ExcelRules
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.Salutation
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.DevetTextField
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.koinInject
import org.koin.core.parameter.parametersOf

const val XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

/** Screen [7] Add guests: tabs Manual · Contacts · Excel (spec/screens.md §7). */
@Composable
fun AddGuestScreen(
    eventId: String,
    initialTab: Int,
    onBack: () -> Unit,
    onPremium: () -> Unit,
    onAddon: () -> Unit,
    onChanged: () -> Unit,
) {
    val c = DevetTheme.colors
    var tab by rememberSaveable { mutableStateOf(initialTab) }
    val snackbar = remember { SnackbarHostState() }
    Box(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding().imePadding()) {
        Column(Modifier.fillMaxSize()) {
            Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
            Text(
                stringResource(R.string.guests_add_title), style = DevetTheme.type.serifTitle, color = c.textPrimary,
                modifier = Modifier.padding(horizontal = Spacing.gutter),
            )
            Row(
                Modifier.padding(horizontal = Spacing.gutter, vertical = Spacing.s2).fillMaxWidth().background(c.bgSunken, Shapes.pill).padding(Spacing.s0_5),
            ) {
                listOf(R.string.guests_tab_manual, R.string.guests_tab_contacts, R.string.guests_tab_excel).forEachIndexed { i, label ->
                    Chip(stringResource(label), tab == i, { tab = i }, Modifier.weight(1f).testTag("tab_$i"))
                }
            }
            when (tab) {
                0 -> ManualTab(eventId, snackbar, onBack, onPremium, onAddon, onChanged)
                1 -> ContactsTab(eventId, snackbar, onPremium, onAddon, onChanged)
                else -> ExcelTab(eventId, snackbar, onPremium, onAddon, onChanged)
            }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun TabColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.gutter, vertical = Spacing.s1),
        verticalArrangement = Arrangement.spacedBy(Spacing.s2),
        content = content,
    )
}

// ---------------------------------------------------------------------------------------------------------------

@Composable
private fun ManualTab(eventId: String, snackbar: SnackbarHostState, onClose: () -> Unit, onPremium: () -> Unit, onAddon: () -> Unit, onChanged: () -> Unit) {
    val vm: ManualGuestViewModel = koinViewModel(key = "manual-$eventId") { parametersOf(eventId) }
    val s by vm.state.collectAsStateWithLifecycle()
    val spec: GuestSpec = koinInject()
    val context = LocalContext.current
    LaunchedEffect(s.added) {
        val name = s.added ?: return@LaunchedEffect
        onChanged()
        vm.addedShown()
        if (s.done) onClose() else snackbar.showSnackbar(context.getString(R.string.guest_added, name))
    }
    TabColumn {
        SalutationPicker(s.form.salutation) { v -> vm.edit { it.copy(salutation = v) } }
        DevetTextField(
            s.form.name, { v -> vm.edit { it.copy(name = v) } }, R.string.guest_name, DevetIcons.user,
            isError = s.nameError, supporting = if (s.nameError) stringResource(R.string.guest_error_name) else null, modifier = Modifier.testTag("name"),
        )
        FamilySwitch(s.form.withFamily) { v -> vm.edit { it.copy(withFamily = v) } }
        CountStepper(s.form.count, { v -> vm.edit { it.copy(count = v) } })
        PhoneField(s.form.phone, { v -> vm.edit { it.copy(phone = v) } }, s.phoneIssue, s.duplicateOf)
        SidePicker(s.form.side) { v -> vm.edit { it.copy(side = v) } }
        DevetTextField(s.form.table, { v -> vm.edit { it.copy(table = v) } }, R.string.guest_table, DevetIcons.globe, modifier = Modifier.testTag("table"))
        LangPicker(s.form.lang) { v -> vm.edit { it.copy(lang = v) } }
        GreetingPreview(spec.displayNames, s.form, s.eventLang)
        if (s.error != null) ErrorBanner(stringResource(s.error!!.messageRes()))
        PrimaryButton(stringResource(R.string.guest_save_next), { vm.save(andNext = true) }, loading = s.saving, modifier = Modifier.testTag("saveNext"))
        LinkButton(stringResource(R.string.common_save), { vm.save(andNext = false) }, Modifier.align(Alignment.CenterHorizontally))
    }
    s.limit?.let { LimitSheet(it, vm::limitShown, onPremium, onAddon) }
}

// ---------------------------------------------------------------------------------------------------------------

@Composable
private fun ContactsTab(eventId: String, snackbar: SnackbarHostState, onPremium: () -> Unit, onAddon: () -> Unit, onChanged: () -> Unit) {
    val vm: ContactsViewModel = koinViewModel(key = "contacts-$eventId") { parametersOf(eventId) }
    val s by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors
    val context = LocalContext.current
    // System picker of one phone number — no contacts permission needed; the URI grant covers the picked row.
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val uri = result.data?.data ?: return@rememberLauncherForActivityResult
        if (result.resultCode != Activity.RESULT_OK) return@rememberLauncherForActivityResult
        val projection = arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER)
        context.contentResolver.query(uri, projection, null, null, null)?.use { cur ->
            if (cur.moveToFirst()) vm.picked(cur.getString(0).orEmpty(), cur.getString(1))
        }
    }
    LaunchedEffect(s.addedCount) {
        val n = s.addedCount ?: return@LaunchedEffect
        onChanged()
        vm.addedShown()
        snackbar.showSnackbar(context.resources.getQuantityString(R.plurals.guests_added_many, n, n))
    }
    TabColumn {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1_5), verticalAlignment = Alignment.CenterVertically) {
            Icon(DevetIcons.contacts, null, tint = c.accentGold, modifier = Modifier.size(32.dp))
            Text(stringResource(R.string.contacts_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary)
        }
        Text(stringResource(R.string.contacts_body), style = DevetTheme.type.body, color = c.textSecondary)
        s.picked.forEach { p ->
            Column(Modifier.fillMaxWidth().background(c.bgSurface, Shapes.card).padding(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(p.name, style = DevetTheme.type.headline, color = c.textPrimary)
                        Text(
                            p.phoneE164 ?: stringResource(R.string.contacts_no_mobile), style = DevetTheme.type.footnote,
                            color = if (p.phoneE164 == null) c.feedbackWarning else c.textSecondary,
                        )
                        if (p.duplicateOf != null) Text(stringResource(R.string.guest_duplicate, p.duplicateOf), style = DevetTheme.type.footnote, color = c.feedbackWarning)
                    }
                    TextButton(onClick = { vm.remove(p.id) }) { Text(stringResource(R.string.contacts_remove), color = c.textLink) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1), modifier = Modifier.horizontalScroll(rememberScrollState())) {
                    Salutation.entries.forEach { sal -> Chip(stringResource(sal.label()), p.salutation == sal, { vm.edit(p.id) { it.copy(salutation = sal) } }) }
                }
                CountStepper(p.count, { v -> vm.edit(p.id) { it.copy(count = v) } })
            }
        }
        val pick = { picker.launch(Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)) }
        if (s.picked.isEmpty()) PrimaryButton(stringResource(R.string.contacts_pick), pick, modifier = Modifier.testTag("pickContact"))
        else LinkButton(stringResource(R.string.contacts_pick_more), pick)
        Text(stringResource(R.string.contacts_privacy), style = DevetTheme.type.footnote, color = c.textSecondary)
        if (s.error != null) ErrorBanner(stringResource(s.error!!.messageRes()))
        if (s.picked.isNotEmpty()) {
            PrimaryButton(pluralStringResource(R.plurals.contacts_add, s.picked.size, s.picked.size), vm::addAll, loading = s.saving, modifier = Modifier.testTag("addContacts"))
        }
    }
    s.limit?.let { LimitSheet(it, vm::limitShown, onPremium, onAddon) }
}

// ---------------------------------------------------------------------------------------------------------------

private val FIELD_LABELS = linkedMapOf(
    "name" to R.string.guest_name, "phone" to R.string.guest_phone, "salutation" to R.string.guest_salutation,
    "invited_count" to R.string.guest_count, "with_family" to R.string.guest_with_family, "side" to R.string.guest_side,
    "table_no" to R.string.guest_table,
)

private val ERROR_TEXTS = mapOf(
    "name_missing" to R.string.excel_err_name_missing, "phone_invalid" to R.string.excel_err_phone_invalid,
    "phone_not_mobile" to R.string.excel_err_phone_not_mobile, "salutation_invalid" to R.string.excel_err_salutation_invalid,
    "invited_count_invalid" to R.string.excel_err_invited_count_invalid, "with_family_invalid" to R.string.excel_err_with_family_invalid,
    "side_invalid" to R.string.excel_err_side_invalid, "table_no_invalid" to R.string.excel_err_table_no_invalid,
)

/** "C" for column index 2. */
private fun letter(i: Int): String = if (i < 26) ('A' + i).toString() else letter(i / 26 - 1) + ('A' + i % 26)

@Composable
private fun ExcelTab(eventId: String, snackbar: SnackbarHostState, onPremium: () -> Unit, onAddon: () -> Unit, onChanged: () -> Unit) {
    val vm: ExcelImportViewModel = koinViewModel(key = "excel-$eventId") { parametersOf(eventId) }
    val s by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors
    val context = LocalContext.current
    val sampleName = stringResource(R.string.excel_sample_name)
    val open = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        val name = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else null }
        vm.open(name ?: "file.xlsx") { context.contentResolver.openInputStream(uri) ?: error("no stream") }
    }
    val saveSample = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(XLSX_MIME)) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        context.contentResolver.openOutputStream(uri)?.use { out -> context.assets.open("sample/guests-sample.xlsx").use { it.copyTo(out) } }
    }
    LaunchedEffect(s.addedCount) {
        val n = s.addedCount ?: return@LaunchedEffect
        onChanged()
        vm.addedShown()
        snackbar.showSnackbar(context.resources.getQuantityString(R.plurals.guests_added_many, n, n))
    }
    TabColumn {
        when (val step = s.step) {
            ExcelStep.Pick, ExcelStep.Reading, is ExcelStep.FileError -> {
                Column(
                    Modifier.fillMaxWidth().background(c.bgSurface, Shapes.card).padding(Spacing.s3),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.s1_5),
                ) {
                    Icon(DevetIcons.upload, null, tint = c.accentGold, modifier = Modifier.size(40.dp))
                    Text(stringResource(R.string.excel_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary)
                    Text(stringResource(R.string.excel_body), style = DevetTheme.type.callout, color = c.textSecondary)
                    PrimaryButton(stringResource(R.string.excel_choose), { open.launch(arrayOf(XLSX_MIME)) }, loading = step == ExcelStep.Reading, modifier = Modifier.testTag("chooseFile"))
                    LinkButton(stringResource(R.string.excel_sample), { saveSample.launch(sampleName) })
                }
                if (step is ExcelStep.FileError) {
                    ErrorBanner(
                        if (step.noRows) stringResource(R.string.excel_no_rows)
                        else stringResource(R.string.excel_file_error) + "\n" + stringResource(R.string.excel_file_error_body),
                    )
                }
            }
            is ExcelStep.Mapping -> MappingStep(step, vm)
            is ExcelStep.Summary -> SummaryStep(step, vm)
        }
        if (s.error != null) ErrorBanner(stringResource(s.error!!.messageRes()))
    }
    s.limit?.let { LimitSheet(it, vm::limitShown, onPremium, onAddon) }
}

@Composable
private fun MappingStep(m: ExcelStep.Mapping, vm: ExcelImportViewModel) {
    val c = DevetTheme.colors
    Text(stringResource(R.string.excel_map_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary)
    Text(stringResource(R.string.excel_map_body, m.fileName, m.rows.size.toString()), style = DevetTheme.type.callout, color = c.textSecondary)
    if (!m.hasName) ErrorBanner(stringResource(R.string.excel_name_column_missing))
    m.headers.forEachIndexed { col, header ->
        var open by remember { mutableStateOf(false) }
        Row(Modifier.fillMaxWidth().background(c.bgSurface, Shapes.control).padding(horizontal = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.excel_column, letter(col), header), style = DevetTheme.type.body, color = c.textPrimary, modifier = Modifier.weight(1f))
            Box {
                TextButton(onClick = { open = true }, modifier = Modifier.testTag("col_$col")) {
                    Text(stringResource(m.columns[col]?.let { FIELD_LABELS[it] } ?: R.string.excel_skip), color = c.textLink, style = DevetTheme.type.headline)
                }
                DropdownMenu(open, { open = false }, containerColor = c.bgRaised) {
                    FIELD_LABELS.forEach { (field, label) ->
                        DropdownMenuItem(text = { Text(stringResource(label)) }, onClick = { open = false; vm.setColumn(col, field) })
                    }
                    DropdownMenuItem(text = { Text(stringResource(R.string.excel_skip)) }, onClick = { open = false; vm.setColumn(col, null) })
                }
            }
        }
    }
    Text(stringResource(R.string.excel_preview), style = DevetTheme.type.caption, color = c.textSecondary)
    Column(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).background(c.bgSurface, Shapes.control).padding(Spacing.s1_5)) {
        m.rows.take(5).forEach { row ->
            Row { m.headers.indices.forEach { i ->
                Text(ExcelRules.asText(row.getOrNull(i) ?: ExcelRules.Cell.Empty), style = DevetTheme.type.footnote, color = c.textPrimary, modifier = Modifier.width(120.dp).padding(end = Spacing.s1), maxLines = 1)
            } }
        }
    }
    PrimaryButton(stringResource(R.string.excel_continue), vm::toSummary, enabled = m.hasName, modifier = Modifier.testTag("toSummary"))
    LinkButton(stringResource(R.string.excel_choose), vm::restart)
}

@Composable
private fun SummaryStep(s: ExcelStep.Summary, vm: ExcelImportViewModel) {
    val c = DevetTheme.colors
    val total = s.guests.size + s.errors.size
    Text(
        stringResource(R.string.excel_summary, s.guests.size.toString(), s.errors.size.toString()),
        style = DevetTheme.type.headline, color = c.textPrimary, modifier = Modifier.testTag("summary"),
    )
    // Ready / error share as a bar.
    Row(Modifier.fillMaxWidth().heightIn(min = 8.dp).background(c.feedbackDangerBg, Shapes.pill)) {
        if (s.guests.isNotEmpty()) Box(Modifier.weight(s.guests.size.toFloat()).heightIn(min = 8.dp).background(c.feedbackSuccess, Shapes.pill))
        if (s.errors.isNotEmpty()) Box(Modifier.weight(s.errors.size.toFloat()).heightIn(min = 8.dp))
    }
    if (s.duplicates > 0) {
        Text(stringResource(R.string.excel_duplicates, s.duplicates.toString()), style = DevetTheme.type.callout, color = c.feedbackWarning)
    }
    if (s.errors.isNotEmpty()) {
        Text(stringResource(R.string.excel_errors_title), style = DevetTheme.type.caption, color = c.textSecondary)
        val texts = ERROR_TEXTS.mapValues { (_, res) -> stringResource(res) }
        Column(Modifier.fillMaxWidth().background(c.bgSurface, Shapes.control).padding(Spacing.s1_5), verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
            s.errors.take(50).forEach { e ->
                val text = e.codes.joinToString(", ") { code -> texts[code] ?: code }
                Text(stringResource(R.string.excel_row, e.sheetRow.toString(), text), style = DevetTheme.type.footnote, color = c.feedbackDanger)
            }
        }
    }
    if (s.importing) {
        Text(stringResource(R.string.excel_importing), style = DevetTheme.type.callout, color = c.textSecondary)
        LinearProgressIndicator(Modifier.fillMaxWidth(), color = c.accentGold, trackColor = c.borderHairline)
    }
    PrimaryButton(
        pluralStringResource(R.plurals.excel_import, s.guests.size, s.guests.size), vm::import,
        enabled = s.guests.isNotEmpty() && total > 0, loading = s.importing, modifier = Modifier.testTag("import"),
    )
    LinkButton(stringResource(R.string.common_back), vm::backToMapping)
}

// ---------------------------------------------------------------------------------------------------------------

/** Limit refusal (screens.md §7 "Limit"): nothing was added; offer premium template or a limit add-on. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LimitSheet(hit: LimitHit, onDismiss: () -> Unit, onPremium: () -> Unit, onAddon: () -> Unit) {
    val c = DevetTheme.colors
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = c.bgRaised) {
        Column(Modifier.padding(horizontal = Spacing.gutter).padding(bottom = Spacing.s4).testTag("limitSheet"), verticalArrangement = Arrangement.spacedBy(Spacing.s1_5)) {
            Text(
                stringResource(R.string.limit_title, hit.limit?.toString() ?: "—"),
                style = DevetTheme.type.serifHeadline, color = c.textPrimary,
            )
            Text(stringResource(R.string.limit_body), style = DevetTheme.type.body, color = c.textSecondary)
            PrimaryButton(stringResource(R.string.limit_premium), { onDismiss(); onPremium() })
            LinkButton(stringResource(R.string.limit_addon), { onDismiss(); onAddon() }, Modifier.align(Alignment.CenterHorizontally))
        }
    }
}
