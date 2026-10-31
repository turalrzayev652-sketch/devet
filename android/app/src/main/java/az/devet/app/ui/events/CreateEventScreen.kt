package az.devet.app.ui.events

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Motion
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel

/** Screen [3] Create event: six steps, then the success screen (spec/screens.md §3). */
@Composable
fun CreateEventScreen(onClose: () -> Unit, onCreated: (String) -> Unit, onChooseTemplate: (String) -> Unit, vm: CreateEventViewModel = koinViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors
    var attempted by rememberSaveable(s.step) { mutableStateOf(false) }
    LaunchedEffect(s.createdId) { s.createdId?.let(onCreated) }
    BackHandler(enabled = s.step > 1 && s.createdId == null) { vm.back() }

    val createdId = s.createdId
    if (createdId != null) {
        CreatedContent(onChooseTemplate = { onChooseTemplate(createdId) }, onClose = onClose)
        return
    }

    Column(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.s1, vertical = Spacing.s0_5), verticalAlignment = Alignment.CenterVertically) {
            if (s.step > 1) BackButton(vm::back) else Spacer(Modifier.size(44.dp))
            Text(
                stringResource(R.string.create_step, s.step.toString(), CreateState.STEPS.toString()),
                style = DevetTheme.type.footnote, color = c.textSecondary, textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f).testTag("stepLabel"),
            )
            IconButton(onClick = onClose) {
                Icon(DevetIcons.close, contentDescription = stringResource(R.string.common_close), tint = c.textPrimary)
            }
        }
        StepProgress(s.step, CreateState.STEPS)
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.gutter, vertical = Spacing.s3),
            verticalArrangement = Arrangement.spacedBy(Spacing.s3),
        ) {
            val question = when (s.step) {
                1 -> R.string.create_q1
                2 -> R.string.create_q2
                3 -> R.string.create_q3
                4 -> R.string.create_q4
                5 -> R.string.create_q5
                else -> R.string.create_q6
            }
            Text(stringResource(question), style = DevetTheme.type.serifHeadline, color = c.textPrimary, modifier = Modifier.testTag("question"))
            when (s.step) {
                1 -> TypeChoices(s.draft.type) { t -> vm.edit { it.copy(type = t) } }
                2 -> NamesFields(s.draft, vm::edit, showRequired = attempted)
                3 -> DateTimeFields(s.draft.startsAt, s.now, { i -> vm.edit { it.copy(startsAt = i) } }, showPastHint = attempted && !s.canNext)
                4 -> VenueFields(s.draft, vm::edit, showRequired = attempted)
                5 -> LanguageChoices(s.draft.defaultLang) { l -> vm.edit { it.copy(defaultLang = l) } }
                else -> TablematesToggle(s.draft.showTablemates) { on -> vm.edit { it.copy(showTablemates = on) } }
            }
            if (s.error != null) {
                ErrorBanner(stringResource(R.string.create_error) + if (s.error == az.devet.app.data.auth.AuthError.Network) "\n" + stringResource(s.error!!.messageRes()) else "")
            }
        }
        Column(Modifier.fillMaxWidth().padding(horizontal = Spacing.gutter, vertical = Spacing.s2), verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
            // The button stays tappable so a tap on an invalid step can show what is missing.
            PrimaryButton(
                stringResource(if (s.isLast) R.string.create_button else R.string.common_next),
                { attempted = true; vm.next() },
                enabled = s.canNext || !attempted, loading = s.creating, modifier = Modifier.testTag("next"),
            )
            if (s.creating) Text(stringResource(R.string.create_creating), style = DevetTheme.type.footnote, color = c.textSecondary, modifier = Modifier.align(Alignment.CenterHorizontally))
            if (s.step > 1) LinkButton(stringResource(R.string.common_back), vm::back, Modifier.align(Alignment.CenterHorizontally))
        }
    }
}

/** Thin gold progress line under the step label. */
@Composable
private fun StepProgress(step: Int, total: Int) {
    val c = DevetTheme.colors
    val reduceMotion = Motion.reduced()
    val fraction by animateFloatAsState(step / total.toFloat(), tween(if (reduceMotion) 0 else Motion.SLOW), label = "progress")
    Box(Modifier.fillMaxWidth().padding(horizontal = Spacing.gutter).height(3.dp).background(c.borderHairline, Shapes.pill)) {
        Box(Modifier.fillMaxWidth(fraction).height(3.dp).background(c.accentGold, Shapes.pill))
    }
}

@Composable
private fun CreatedContent(onChooseTemplate: () -> Unit, onClose: () -> Unit) {
    val c = DevetTheme.colors
    val reduceMotion = Motion.reduced()
    var shown by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    // One-time sparkle (design.md §5); with reduced motion the mark is static.
    val scale by animateFloatAsState(if (shown || reduceMotion) 1f else 0.6f, tween(if (reduceMotion) 0 else 600), label = "sparkle")
    Column(
        Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding().padding(Spacing.gutter).testTag("created"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.s1_5, Alignment.CenterVertically),
    ) {
        Icon(DevetIcons.envelope, contentDescription = null, tint = c.accentGold, modifier = Modifier.size(160.dp, 124.dp).scale(scale))
        Text(stringResource(R.string.create_success_title), style = DevetTheme.type.serifTitle, color = c.textPrimary, textAlign = TextAlign.Center)
        Text(stringResource(R.string.create_success_body), style = DevetTheme.type.body, color = c.textSecondary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(Spacing.s2))
        PrimaryButton(stringResource(R.string.create_success_choose_template), onChooseTemplate, modifier = Modifier.testTag("chooseTemplate"))
        LinkButton(stringResource(R.string.common_close), onClose)
    }
}

/** True when the system asks for no animations (design.md §5 reduced motion). */
@Composable
fun Motion.reduced(): Boolean {
    val context = LocalContext.current
    return android.provider.Settings.Global.getFloat(context.contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
}
