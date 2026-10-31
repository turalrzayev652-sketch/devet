package az.devet.app.ui.events

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.activity.compose.BackHandler
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.data.events.EventSummary
import az.devet.app.data.events.MemberRole
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel

/** Screen [2] My events (spec/screens.md §2). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventsScreen(
    onSettings: () -> Unit,
    onOpen: (EventSummary) -> Unit,
    onCreate: () -> Unit,
    onEdit: (EventSummary) -> Unit,
    onJoin: () -> Unit,
    reloadKey: Int = 0,
    vm: EventsViewModel = koinViewModel(),
) {
    val s by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors
    val snackbar = remember { SnackbarHostState() }
    val context = LocalContext.current
    LaunchedEffect(reloadKey) { if (reloadKey > 0) vm.load(refresh = true) }
    LaunchedEffect(s.message, s.actionError) {
        val text = when {
            s.message == EventsMessage.Deleted -> context.getString(R.string.events_deleted)
            s.actionError != null -> context.getString(s.actionError!!.messageRes())
            else -> return@LaunchedEffect
        }
        vm.messageShown()
        snackbar.showSnackbar(text)
    }
    BackHandler(enabled = s.showArchive) { vm.showArchive(false) }

    val list = if (s.showArchive) s.archived else s.active
    Box(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding()) {
        Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().padding(start = Spacing.gutter, end = Spacing.s1, top = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
                if (s.showArchive) BackButton { vm.showArchive(false) }
                Text(
                    stringResource(if (s.showArchive) R.string.events_archive_title else R.string.events_title),
                    style = DevetTheme.type.serifDisplay, color = c.textPrimary, modifier = Modifier.weight(1f).testTag("eventsTitle"),
                )
                IconButton(onClick = onSettings, modifier = Modifier.testTag("settings")) {
                    Icon(DevetIcons.user, contentDescription = stringResource(R.string.settings_title), tint = c.textPrimary)
                }
            }
            PullToRefreshBox(isRefreshing = s.refreshing, onRefresh = { vm.load(refresh = true) }, modifier = Modifier.weight(1f)) {
                when {
                    s.loading -> Skeletons()
                    list.isEmpty() && !s.showArchive && s.error == null -> EmptyState(onCreate, onJoin)
                    else -> LazyColumn(
                        Modifier.fillMaxSize().testTag("eventList"),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(Spacing.gutter, Spacing.s2),
                        verticalArrangement = Arrangement.spacedBy(Spacing.s2),
                    ) {
                        if (s.error != null) item {
                            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                                ErrorBanner(stringResource(R.string.events_load_error) + " " + stringResource(s.error!!.messageRes()))
                                LinkButton(stringResource(R.string.common_retry), { vm.load() })
                            }
                        }
                        items(list, key = { it.id }) { e ->
                            EventCard(
                                e, onOpen = { onOpen(e) }, onEdit = { onEdit(e) }, onDelete = { vm.askDelete(e) },
                                archived = s.showArchive, canUnarchive = s.canUnarchive(e),
                                onArchive = { vm.setArchived(e, !s.showArchive) },
                            )
                        }
                        if (!s.showArchive && s.archived.isNotEmpty()) item {
                            LinkButton(stringResource(R.string.events_archive, s.archived.size.toString()), { vm.showArchive(true) }, Modifier.testTag("archiveLink"))
                        }
                        item { Spacer(Modifier.height(120.dp)) }
                    }
                }
            }
        }
        if (!s.showArchive && !s.loading && s.active.isNotEmpty()) {
            Column(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(c.bgCanvas).padding(horizontal = Spacing.gutter, vertical = Spacing.s2),
                verticalArrangement = Arrangement.spacedBy(Spacing.s1),
            ) {
                PrimaryButton(stringResource(R.string.events_new), onCreate, modifier = Modifier.testTag("newEvent"))
                LinkButton(stringResource(R.string.events_join), onJoin, Modifier.align(Alignment.CenterHorizontally))
            }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).padding(bottom = 120.dp))
    }

    s.deleteTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { if (!s.deleting) vm.cancelDelete() },
            title = { Text(stringResource(R.string.events_delete_title, target.titleNames), style = DevetTheme.type.serifHeadline) },
            text = { Text(pluralStringResource(R.plurals.events_delete_body, target.guestCount, target.guestCount), style = DevetTheme.type.body) },
            confirmButton = {
                TextButton(onClick = vm::confirmDelete, enabled = !s.deleting, modifier = Modifier.testTag("confirmDelete")) {
                    Text(stringResource(R.string.events_delete_confirm), color = c.feedbackDanger, style = DevetTheme.type.headline)
                }
            },
            dismissButton = {
                TextButton(onClick = vm::cancelDelete, enabled = !s.deleting) {
                    Text(stringResource(R.string.common_cancel), color = c.textLink, style = DevetTheme.type.headline)
                }
            },
            containerColor = c.bgRaised,
        )
    }
}

@Composable
private fun EventCard(
    e: EventSummary,
    onOpen: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    archived: Boolean,
    canUnarchive: Boolean,
    onArchive: () -> Unit,
) {
    val c = DevetTheme.colors
    var menu by rememberSaveable { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().background(c.bgSurface, Shapes.card).clickable(onClick = onOpen).testTag("event_${e.id}")) {
        // Template thumbnail arrives with templates (T44); until then a decorative band.
        Box(Modifier.fillMaxWidth().height(88.dp).background(c.brandSubtle, Shapes.card)) {
            Icon(DevetIcons.botanical, contentDescription = null, tint = c.accentGold, modifier = Modifier.fillMaxSize().padding(Spacing.s1))
            Text(
                stringResource(if (e.role == MemberRole.Owner) R.string.events_role_owner else R.string.events_role_cohost),
                style = DevetTheme.type.caption, color = c.textPrimary,
                modifier = Modifier.align(Alignment.TopStart).padding(Spacing.s1_5).background(c.bgSurface, Shapes.pill)
                    .padding(horizontal = Spacing.s1, vertical = Spacing.s0_5),
            )
            Box(Modifier.align(Alignment.TopEnd)) {
                IconButton(onClick = { menu = true }, modifier = Modifier.testTag("menu_${e.id}")) {
                    Icon(DevetIcons.more, contentDescription = stringResource(R.string.events_menu), tint = c.textPrimary)
                }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, containerColor = c.bgRaised) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.events_menu_edit)) }, onClick = { menu = false; onEdit() })
                    if (!archived || canUnarchive) {
                        DropdownMenuItem(
                            text = { Text(stringResource(if (archived) R.string.events_menu_unarchive else R.string.events_menu_archive)) },
                            onClick = { menu = false; onArchive() },
                        )
                    }
                    if (e.role == MemberRole.Owner) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.events_menu_delete), color = c.feedbackDanger) },
                            onClick = { menu = false; onDelete() }, modifier = Modifier.testTag("delete_${e.id}"),
                        )
                    }
                }
            }
        }
        Column(Modifier.padding(Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
            Text(
                stringResource(e.type.label()), style = DevetTheme.type.caption, color = c.brandPrimary,
                modifier = Modifier.background(c.brandSubtle, Shapes.pill).padding(horizontal = Spacing.s1, vertical = Spacing.s0_5),
            )
            Text(e.titleNames, style = DevetTheme.type.serifTitle, color = c.textPrimary)
            Text("${formatEventDate(e.startsAt)} · ${e.venueName}", style = DevetTheme.type.footnote, color = c.textSecondary)
            Text(
                pluralStringResource(R.plurals.events_stat_coming, e.comingPeople, e.comingPeople) + " · " +
                    pluralStringResource(R.plurals.events_stat_no_answer, e.noAnswer, e.noAnswer),
                style = DevetTheme.type.footnote, color = c.textPrimary,
            )
        }
    }
}

@Composable
private fun EmptyState(onCreate: () -> Unit, onJoin: () -> Unit) {
    val c = DevetTheme.colors
    Column(
        Modifier.fillMaxSize().padding(Spacing.gutter).testTag("emptyEvents"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.s1_5, Alignment.CenterVertically),
    ) {
        Icon(DevetIcons.envelope, contentDescription = null, tint = c.accentGold, modifier = Modifier.size(160.dp, 124.dp))
        Text(stringResource(R.string.events_empty_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary, textAlign = TextAlign.Center)
        Text(stringResource(R.string.events_empty_body), style = DevetTheme.type.body, color = c.textSecondary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(Spacing.s2))
        PrimaryButton(stringResource(R.string.events_empty_create), onCreate, modifier = Modifier.testTag("createFirst"))
        LinkButton(stringResource(R.string.events_join), onJoin)
    }
}

@Composable
private fun Skeletons() {
    Column(Modifier.fillMaxSize().padding(Spacing.gutter), verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        repeat(2) {
            Box(Modifier.fillMaxWidth().height(200.dp).background(DevetTheme.colors.bgSunken, Shapes.card))
        }
    }
}
