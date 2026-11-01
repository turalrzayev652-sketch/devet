package az.devet.app.ui.guests

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.GuestStatus
import az.devet.app.data.guests.Side
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.DevetTextField
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.send.PreviewListScreen
import az.devet.app.ui.send.PreviewListViewModel
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.koinInject
import org.koin.core.parameter.parametersOf

/** Inside an event: bottom navigation Guests · Send · Statistics · More (screens.md §0). Send/Stats/More come later. */
@Composable
fun EventScreen(
    eventId: String,
    title: String,
    isOwner: Boolean,
    reloadKey: Int,
    onBack: () -> Unit,
    onAdd: (tab: Int) -> Unit,
    onLimit: () -> Unit,
) {
    val c = DevetTheme.colors
    var tab by rememberSaveable { mutableStateOf(0) }
    val items = listOf(
        R.string.nav_guests to DevetIcons.user, R.string.nav_send to DevetIcons.upload,
        R.string.nav_stats to DevetIcons.check, R.string.nav_more to DevetIcons.more,
    )
    Scaffold(
        containerColor = c.bgCanvas,
        bottomBar = {
            NavigationBar(containerColor = c.bgSurface) {
                items.forEachIndexed { i, (label, icon) ->
                    NavigationBarItem(
                        selected = tab == i, onClick = { tab = i },
                        icon = { Icon(icon, contentDescription = null) },
                        label = { Text(stringResource(label), style = DevetTheme.type.caption) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = c.brandPrimary, selectedTextColor = c.brandPrimary, indicatorColor = c.brandSubtle,
                            unselectedIconColor = c.textSecondary, unselectedTextColor = c.textSecondary,
                        ),
                        modifier = Modifier.testTag("nav_$i"),
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            if (tab == 0) GuestListContent(eventId, title, isOwner, reloadKey, onBack, onAdd, onLimit)
            else if (tab == 1) {
                val vm: PreviewListViewModel = koinViewModel(key = "preview-$eventId") { parametersOf(eventId) }
                PreviewListScreen(vm, onReady = { /* TODO: T48A send flow */ })
            }
            else Column(Modifier.fillMaxSize()) {
                Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(stringResource(R.string.common_coming_soon), style = DevetTheme.type.callout, color = c.textSecondary, textAlign = TextAlign.Center)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun GuestListContent(
    eventId: String,
    title: String,
    isOwner: Boolean,
    reloadKey: Int,
    onBack: () -> Unit,
    onAdd: (tab: Int) -> Unit,
    onLimit: () -> Unit,
) {
    val vm: GuestListViewModel = koinViewModel(key = "guests-$eventId") { parametersOf(eventId, isOwner) }
    val s by vm.state.collectAsStateWithLifecycle()
    val spec: GuestSpec = koinInject()
    val c = DevetTheme.colors
    val context = LocalContext.current
    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(reloadKey) { if (reloadKey > 0) vm.load(refresh = true) }
    LaunchedEffect(s.message, s.actionError) {
        val text = when {
            s.message == GuestMessage.Saved -> context.getString(R.string.settings_saved)
            s.message == GuestMessage.Deleted -> context.getString(R.string.guests_deleted)
            s.actionError != null -> context.getString(s.actionError!!.messageRes())
            else -> return@LaunchedEffect
        }
        vm.messageShown()
        snackbar.showSnackbar(text)
    }

    Box(Modifier.fillMaxSize().background(c.bgCanvas)) {
        Column(Modifier.fillMaxSize()) {
            if (s.selecting) SelectionBar(s, vm) else {
                Row(Modifier.fillMaxWidth().padding(end = Spacing.gutter, top = Spacing.s0_5), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.padding(start = Spacing.s1)) { BackButton(onBack) }
                    Text(title, style = DevetTheme.type.footnote, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                }
            }
            if (!s.loading && s.guests.isEmpty() && s.error == null) {
                EmptyGuests(onAdd)
                return@Column
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.gutter, vertical = Spacing.s1), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.guests_title), style = DevetTheme.type.serifTitle, color = c.textPrimary, modifier = Modifier.weight(1f))
                LimitRing(s.guests.size, s.limit, s.level)
            }
            if (s.level != LimitLevel.Normal && s.limit != null) {
                val near = s.level == LimitLevel.Near
                Text(
                    if (near) pluralStringResource(R.plurals.limit_near, s.limit!! - s.guests.size, s.limit!! - s.guests.size) else stringResource(R.string.limit_full),
                    style = DevetTheme.type.footnote, color = if (near) c.accentGoldText else c.feedbackDanger,
                    modifier = Modifier.padding(horizontal = Spacing.gutter).background(if (near) c.accentGoldSubtle else c.feedbackDangerBg, Shapes.pill)
                        .combinedClickable(onClick = onLimit).padding(horizontal = Spacing.s1_5, vertical = Spacing.s0_5).testTag("limitBadge"),
                )
            }
            DevetTextField(
                s.query, vm::search, R.string.guests_search, DevetIcons.globe,
                modifier = Modifier.padding(horizontal = Spacing.gutter, vertical = Spacing.s1).testTag("search"),
            )
            LazyRow(contentPadding = PaddingValues(horizontal = Spacing.gutter), horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                items(GuestFilter.entries) { f ->
                    Chip(stringResource(R.string.guests_chip, stringResource(f.label()), s.count(f).toString()), s.filter == f, { vm.filter(f) }, Modifier.testTag("filter_${f.name}"))
                }
            }
            if (s.error != null) {
                Column(Modifier.padding(horizontal = Spacing.gutter, vertical = Spacing.s1)) {
                    ErrorBanner(stringResource(R.string.guests_load_error) + " " + stringResource(s.error!!.messageRes()))
                    LinkButton(stringResource(R.string.common_retry), { vm.load() })
                }
            }
            PullToRefreshBox(isRefreshing = s.refreshing, onRefresh = { vm.load(refresh = true) }, modifier = Modifier.weight(1f)) {
                when {
                    s.loading -> Column(Modifier.padding(Spacing.gutter), verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                        repeat(6) { Box(Modifier.fillMaxWidth().height(56.dp).background(c.bgSunken, Shapes.control)) }
                    }
                    s.visible.isEmpty() && s.query.isNotBlank() -> Column(
                        Modifier.fillMaxSize().padding(Spacing.gutter), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(Spacing.s1, Alignment.CenterVertically),
                    ) {
                        Text(stringResource(R.string.guests_no_results, s.query.trim()), style = DevetTheme.type.serifHeadline, color = c.textPrimary, textAlign = TextAlign.Center)
                        Text(stringResource(R.string.guests_no_results_body), style = DevetTheme.type.callout, color = c.textSecondary, textAlign = TextAlign.Center)
                    }
                    else -> LazyColumn(Modifier.fillMaxSize().testTag("guestList"), contentPadding = PaddingValues(top = Spacing.s1, bottom = 96.dp)) {
                        items(s.visible, key = { it.id }) { g ->
                            GuestRow(g, spec, s.eventLang, selected = g.id in s.selected, selecting = s.selecting, isOwner = vm.isOwner, vm = vm)
                        }
                    }
                }
            }
        }
        if (!s.selecting && s.guests.isNotEmpty()) {
            ExtendedFloatingActionButton(
                onClick = { onAdd(0) }, containerColor = c.brandPrimary, contentColor = c.textOnBrand,
                modifier = Modifier.align(Alignment.BottomEnd).padding(Spacing.s2).testTag("fab"),
            ) { Text(stringResource(R.string.guests_add), style = DevetTheme.type.headline) }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).padding(bottom = 72.dp))
    }

    s.editing?.let { EditSheet(it, spec, s.eventLang, vm) }
    s.confirmDelete?.let { ids ->
        val single = ids.singleOrNull()?.let { id -> s.guests.firstOrNull { it.id == id } }
        AlertDialog(
            onDismissRequest = vm::cancelDelete,
            title = {
                Text(
                    if (single != null) stringResource(R.string.guests_delete_title, spec.displayNames.displayName(single.name, single.salutation, single.withFamily, single.lang ?: s.eventLang))
                    else pluralStringResource(R.plurals.guests_bulk_delete_title, ids.size, ids.size),
                    style = DevetTheme.type.serifHeadline,
                )
            },
            text = { Text(stringResource(R.string.guests_delete_body), style = DevetTheme.type.body) },
            confirmButton = {
                TextButton(onClick = vm::confirmDelete, enabled = !s.busy, modifier = Modifier.testTag("confirmDelete")) {
                    Text(stringResource(R.string.events_delete_confirm), color = c.feedbackDanger, style = DevetTheme.type.headline)
                }
            },
            dismissButton = { TextButton(onClick = vm::cancelDelete) { Text(stringResource(R.string.common_cancel), color = c.textLink) } },
            containerColor = c.bgRaised,
        )
    }
    if (s.bulkTable) BulkTableDialog(s.busy, vm)
}

private fun GuestFilter.label() = when (this) {
    GuestFilter.All -> R.string.guests_filter_all
    GuestFilter.Groom -> R.string.guest_side_groom
    GuestFilter.Bride -> R.string.guest_side_bride
    GuestFilter.Coming -> R.string.guests_filter_coming
    GuestFilter.Declined -> R.string.guests_filter_declined
    GuestFilter.NoAnswer -> R.string.guests_filter_pending
    GuestFilter.Unsent -> R.string.guests_filter_unsent
    GuestFilter.NoTable -> R.string.guests_filter_no_table
}

/** "84/100" ring; gold near the limit, red when full. */
@Composable
private fun LimitRing(count: Int, limit: Int?, level: LimitLevel) {
    val c = DevetTheme.colors
    val color = when (level) { LimitLevel.Normal -> c.brandPrimary; LimitLevel.Near -> c.accentGoldStrong; LimitLevel.Full -> c.feedbackDanger }
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(64.dp).testTag("limitRing")) {
        CircularProgressIndicator(
            progress = { if (limit == null || limit == 0) 0f else (count.toFloat() / limit).coerceAtMost(1f) },
            modifier = Modifier.fillMaxSize(), color = color, trackColor = c.borderHairline, strokeWidth = 4.dp,
        )
        Text(if (limit != null) "$count/$limit" else "$count", style = DevetTheme.type.footnote, color = c.textPrimary)
    }
}

/** Status pill: always text, colour only helps (design.md §2.2). */
@Composable
fun StatusPill(g: Guest) {
    val c = DevetTheme.colors
    val (colors, text) = when (g.status) {
        GuestStatus.Coming -> c.statusComing to stringResource(R.string.status_coming, g.rsvpCount.toString())
        GuestStatus.Declined -> c.statusDeclined to stringResource(R.string.status_declined)
        GuestStatus.Viewed -> c.statusViewed to stringResource(R.string.status_viewed)
        GuestStatus.Pending -> c.statusPending to stringResource(R.string.status_pending)
        GuestStatus.Unsent -> c.statusUnsent to stringResource(R.string.status_unsent)
    }
    Row(
        Modifier.background(colors.bg, Shapes.pill).padding(horizontal = Spacing.s1, vertical = Spacing.s0_5),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s0_5),
    ) {
        Box(Modifier.size(6.dp).background(colors.fg, CircleShape))
        Text(text, style = DevetTheme.type.caption, color = colors.text, maxLines = 1)
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun GuestRow(g: Guest, spec: GuestSpec, eventLang: String, selected: Boolean, selecting: Boolean, isOwner: Boolean, vm: GuestListViewModel) {
    val c = DevetTheme.colors
    var actions by remember { mutableStateOf(false) }
    // Swipe left opens the row actions (Edit / Delete — delete for the owner only), screens.md §6.
    val swipe = rememberSwipeToDismissBoxState(confirmValueChange = { v -> if (v == SwipeToDismissBoxValue.EndToStart) actions = true; false })
    val line2 = listOfNotNull(
        pluralStringResource(R.plurals.guests_people, g.invitedCount, g.invitedCount),
        g.tableNo?.takeIf { it.isNotBlank() }?.let { stringResource(R.string.guests_table_short, it) },
        g.side.takeIf { it != Side.None }?.let { stringResource(it.label()) },
    ).joinToString(" · ")
    SwipeToDismissBox(swipe, enableDismissFromStartToEnd = false, gesturesEnabled = !selecting, backgroundContent = {
        Box(Modifier.fillMaxSize().background(c.brandSubtle))
    }) {
        Row(
            Modifier.fillMaxWidth().background(if (selected) c.brandSubtle else c.bgCanvas)
                .combinedClickable(onClick = { if (selecting) vm.toggle(g.id) else vm.open(g) }, onLongClick = { vm.toggle(g.id) })
                .padding(horizontal = Spacing.gutter, vertical = Spacing.s1_5).testTag("guest_${g.id}"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.s1_5),
        ) {
            if (selecting) {
                Box(
                    Modifier.size(22.dp).border(1.5.dp, if (selected) c.brandPrimary else c.borderControl, CircleShape)
                        .background(if (selected) c.brandPrimary else Color.Transparent, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { if (selected) Icon(DevetIcons.check, null, tint = c.textOnBrand, modifier = Modifier.size(14.dp)) }
            }
            Column(Modifier.weight(1f)) {
                Text(spec.displayNames.displayName(g.name, g.salutation, g.withFamily, g.lang ?: eventLang), style = DevetTheme.type.headline, color = c.textPrimary)
                Text(line2, style = DevetTheme.type.footnote, color = c.textSecondary)
            }
            StatusPill(g)
        }
    }
    DropdownMenu(actions, { actions = false }, containerColor = c.bgRaised) {
        DropdownMenuItem(text = { Text(stringResource(R.string.events_menu_edit)) }, onClick = { actions = false; vm.open(g) })
        if (isOwner) DropdownMenuItem(text = { Text(stringResource(R.string.events_menu_delete), color = c.feedbackDanger) }, onClick = { actions = false; vm.askDelete(listOf(g.id)) })
    }
}

/** Multi-select top bar + actions: Assign table · Side · Delete (owner), screens.md §6. */
@Composable
private fun SelectionBar(s: GuestListState, vm: GuestListViewModel) {
    val c = DevetTheme.colors
    var sideMenu by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().background(c.bgSurface).padding(horizontal = Spacing.s2, vertical = Spacing.s1)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.guests_selected, s.selected.size.toString()), style = DevetTheme.type.headline, color = c.textPrimary, modifier = Modifier.weight(1f).testTag("selectedCount"))
            TextButton(onClick = vm::clearSelection) { Text(stringResource(R.string.guests_done), color = c.textLink) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
            Chip(stringResource(R.string.guests_bulk_table), false, vm::openBulkTable, Modifier.testTag("bulkTable"))
            Box {
                Chip(stringResource(R.string.guest_side), false, { sideMenu = true })
                DropdownMenu(sideMenu, { sideMenu = false }, containerColor = c.bgRaised) {
                    Side.entries.forEach { side -> DropdownMenuItem(text = { Text(stringResource(side.label())) }, onClick = { sideMenu = false; vm.bulkSide(side) }) }
                }
            }
            if (vm.isOwner) Chip(stringResource(R.string.events_menu_delete), false, { vm.askDelete(s.selected.toList()) })
        }
    }
}

@Composable
private fun BulkTableDialog(busy: Boolean, vm: GuestListViewModel) {
    val c = DevetTheme.colors
    var table by rememberSaveable { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = vm::closeBulkTable,
        title = { Text(stringResource(R.string.guests_bulk_table), style = DevetTheme.type.serifHeadline) },
        text = { DevetTextField(table, { table = it.take(12) }, R.string.guests_bulk_table_hint, DevetIcons.globe, modifier = Modifier.testTag("bulkTableInput")) },
        confirmButton = {
            TextButton(onClick = { vm.bulkTable(table) }, enabled = !busy, modifier = Modifier.testTag("bulkApply")) {
                Text(stringResource(R.string.guests_bulk_apply), color = c.textLink, style = DevetTheme.type.headline)
            }
        },
        dismissButton = { TextButton(onClick = vm::closeBulkTable) { Text(stringResource(R.string.common_cancel), color = c.textLink) } },
        containerColor = c.bgRaised,
    )
}

/** Edit sheet (screens.md §6.1). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditSheet(e: EditGuest, spec: GuestSpec, eventLang: String, vm: GuestListViewModel) {
    val c = DevetTheme.colors
    ModalBottomSheet(onDismissRequest = vm::closeEdit, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = c.bgCanvas) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.gutter).padding(bottom = Spacing.s4).testTag("editSheet"),
            verticalArrangement = Arrangement.spacedBy(Spacing.s2),
        ) {
            Text(stringResource(R.string.guests_edit_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary)
            SalutationPicker(e.form.salutation) { v -> vm.edit { it.copy(salutation = v) } }
            DevetTextField(
                e.form.name, { v -> vm.edit { it.copy(name = v) } }, R.string.guest_name, DevetIcons.user,
                isError = e.nameError, supporting = if (e.nameError) stringResource(R.string.guest_error_name) else null, modifier = Modifier.testTag("editName"),
            )
            FamilySwitch(e.form.withFamily) { v -> vm.edit { it.copy(withFamily = v) } }
            CountStepper(e.form.count, { v -> vm.edit { it.copy(count = v) } })
            PhoneField(e.form.phone, { v -> vm.edit { it.copy(phone = v) } }, e.phoneIssue, null)
            SidePicker(e.form.side) { v -> vm.edit { it.copy(side = v) } }
            DevetTextField(e.form.table, { v -> vm.edit { it.copy(table = v) } }, R.string.guest_table, DevetIcons.globe, modifier = Modifier.testTag("editTable"))
            LangPicker(e.form.lang) { v -> vm.edit { it.copy(lang = v) } }
            GreetingPreview(spec.displayNames, e.form, eventLang)
            PrimaryButton(stringResource(R.string.common_save), vm::saveEdit, loading = e.saving, modifier = Modifier.testTag("editSave"))
            if (vm.isOwner) {
                LinkButton(stringResource(R.string.guests_delete), { vm.askDelete(listOf(e.guest.id)) }, Modifier.align(Alignment.CenterHorizontally))
            }
            Spacer(Modifier.heightIn(min = Spacing.s2))
        }
    }
}

/** Empty state of [6]: three ways to add guests. */
@Composable
private fun EmptyGuests(onAdd: (Int) -> Unit) {
    val c = DevetTheme.colors
    Column(
        Modifier.fillMaxSize().padding(Spacing.gutter).testTag("emptyGuests"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.s1_5, Alignment.CenterVertically),
    ) {
        Icon(DevetIcons.envelope, null, tint = c.accentGold, modifier = Modifier.size(160.dp, 124.dp))
        Text(stringResource(R.string.guests_empty_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary)
        Text(stringResource(R.string.guests_empty_body), style = DevetTheme.type.body, color = c.textSecondary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(Spacing.s2))
        PrimaryButton(stringResource(R.string.guests_add_manual), { onAdd(0) }, modifier = Modifier.testTag("addManual"))
        LinkButton(stringResource(R.string.guests_add_contacts), { onAdd(1) })
        LinkButton(stringResource(R.string.guests_add_excel), { onAdd(2) })
    }
}
