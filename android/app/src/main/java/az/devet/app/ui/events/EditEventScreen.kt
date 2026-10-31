package az.devet.app.ui.events

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/** Screen [3] in edit mode: the same fields as one page with sections (screens.md §3). Owner and co-host. */
@Composable
fun EditEventScreen(eventId: String, onBack: () -> Unit, onSaved: () -> Unit, vm: EditEventViewModel = koinViewModel { parametersOf(eventId) }) {
    val s by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors
    LaunchedEffect(s.saved) { if (s.saved) onSaved() }
    Column(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding().imePadding()) {
        Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.gutter, vertical = Spacing.s1),
            verticalArrangement = Arrangement.spacedBy(Spacing.s3),
        ) {
            Text(stringResource(R.string.edit_title), style = DevetTheme.type.serifTitle, color = c.textPrimary)
            when {
                s.loading -> repeat(3) { Box(Modifier.fillMaxWidth().height(120.dp).background(c.bgSunken, Shapes.card)) }
                s.original == null -> {
                    ErrorBanner(stringResource((s.error ?: az.devet.app.data.auth.AuthError.Unknown).messageRes()))
                    LinkButton(stringResource(R.string.common_retry), vm::load)
                }
                else -> {
                    Section(R.string.edit_section_type) { TypeChoices(s.draft.type) { t -> vm.edit { it.copy(type = t) } } }
                    Section(R.string.create_names) { NamesFields(s.draft, vm::edit, showRequired = true) }
                    Section(R.string.edit_section_date_time) {
                        DateTimeFields(s.draft.startsAt, s.now, { i -> vm.edit { it.copy(startsAt = i) } }, showPastHint = !s.dateOk)
                    }
                    Section(R.string.edit_section_venue) { VenueFields(s.draft, vm::edit, showRequired = true) }
                    Section(R.string.create_q5) { LanguageChoices(s.draft.defaultLang) { l -> vm.edit { it.copy(defaultLang = l) } } }
                    Section(R.string.create_q6) { TablematesToggle(s.draft.showTablemates) { on -> vm.edit { it.copy(showTablemates = on) } } }
                    if (s.error != null) ErrorBanner(stringResource(s.error!!.messageRes()))
                }
            }
        }
        if (s.original != null) {
            PrimaryButton(
                stringResource(R.string.common_save), vm::save, enabled = s.canSave, loading = s.saving,
                modifier = Modifier.padding(horizontal = Spacing.gutter, vertical = Spacing.s2).testTag("save"),
            )
        }
    }
}

@Composable
private fun Section(@StringRes title: Int, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1_5)) {
        Text(stringResource(title).uppercase(), style = DevetTheme.type.caption, color = DevetTheme.colors.textSecondary)
        content()
    }
}
