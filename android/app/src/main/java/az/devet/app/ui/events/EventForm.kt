package az.devet.app.ui.events

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import az.devet.app.R
import az.devet.app.data.AppLanguage
import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventRules
import az.devet.app.data.events.EventType
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.DevetTextField
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Sizes
import az.devet.app.ui.theme.Spacing
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

// Form blocks shared by the create wizard and the edit page (screens.md §3).

@StringRes
fun EventType.label(): Int = when (this) {
    EventType.Wedding -> R.string.event_type_wedding
    EventType.Engagement -> R.string.event_type_engagement
    EventType.Henna -> R.string.event_type_henna
    EventType.Birthday -> R.string.event_type_birthday
    EventType.Jubilee -> R.string.event_type_jubilee
}

private val LANGUAGE_NAMES = mapOf("az" to R.string.lang_az, "ru" to R.string.lang_ru, "en" to R.string.lang_en, "tr" to R.string.lang_tr)

/** "3 avqust 2027, 17:00" in Baku time, month names in the UI language. */
@Composable
fun formatEventDate(instant: Instant): String {
    val locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()
    return remember(instant, locale) {
        DateTimeFormatter.ofPattern("d MMMM yyyy, HH:mm", locale).withZone(EventRules.ZONE).format(instant)
    }
}

/** Large selectable card with a radio-like state (event type, language). */
@Composable
fun ChoiceCard(text: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val c = DevetTheme.colors
    Row(
        modifier.fillMaxWidth().heightIn(min = 60.dp)
            .background(if (selected) c.brandSubtle else c.bgSurface, Shapes.card)
            .border(if (selected) 2.dp else 1.dp, if (selected) c.brandPrimary else c.borderHairline, Shapes.card)
            .selectable(selected, role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, style = DevetTheme.type.headline, color = c.textPrimary, modifier = Modifier.weight(1f))
        if (selected) Icon(DevetIcons.check, contentDescription = null, tint = c.brandPrimary)
    }
}

@Composable
fun TypeChoices(selected: EventType?, onSelect: (EventType) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1_5)) {
        EventType.entries.forEach { t ->
            ChoiceCard(stringResource(t.label()), selected == t, { onSelect(t) }, Modifier.testTag("type_${t.key}"))
        }
    }
}

@Composable
fun NamesFields(draft: EventDraft, onChange: ((EventDraft) -> EventDraft) -> Unit, showRequired: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        DevetTextField(
            draft.titleNames, { v -> onChange { it.copy(titleNames = v.take(EventRules.MAX_TITLE)) } }, R.string.create_names, DevetIcons.user,
            isError = showRequired && draft.titleNames.isBlank(),
            supporting = stringResource(if (showRequired && draft.titleNames.isBlank()) R.string.create_names_required else R.string.create_names_hint),
            modifier = Modifier.testTag("titleNames"),
        )
        DevetTextField(
            draft.hostNames, { v -> onChange { it.copy(hostNames = v.take(EventRules.MAX_HOSTS)) } }, R.string.create_parents, DevetIcons.user,
            supporting = stringResource(R.string.create_parents_help), modifier = Modifier.testTag("hostNames"),
        )
    }
}

/** Date + time pickers in Baku time; days before today cannot be picked (§15.4). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateTimeFields(startsAt: Instant?, now: Instant, onChange: (Instant) -> Unit, showPastHint: Boolean) {
    val c = DevetTheme.colors
    var pickDate by rememberSaveable { mutableStateOf(false) }
    var pickTime by rememberSaveable { mutableStateOf(false) }
    val zoned = startsAt?.atZone(EventRules.ZONE)
    val today = now.atZone(EventRules.ZONE).toLocalDate()
    val date = zoned?.toLocalDate()
    val time = zoned?.toLocalTime() ?: LocalTime.of(18, 0)
    val locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()

    fun set(d: LocalDate, t: LocalTime) = onChange(d.atTime(t).atZone(EventRules.ZONE).toInstant())

    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        PickerRow(
            R.string.create_date, date?.format(DateTimeFormatter.ofPattern("d MMMM yyyy, EEEE", locale)),
            Modifier.testTag("date"),
        ) { pickDate = true }
        PickerRow(R.string.create_time, time.format(DateTimeFormatter.ofPattern("HH:mm")), Modifier.testTag("time")) { pickTime = true }
        if (showPastHint) Text(stringResource(R.string.create_past_hint), style = DevetTheme.type.footnote, color = c.feedbackDanger)
    }

    if (pickDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = (date ?: today.plusDays(1)).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) =
                    !Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate().isBefore(today)
                override fun isSelectableYear(year: Int) = year >= today.year
            },
        )
        DatePickerDialog(
            onDismissRequest = { pickDate = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { set(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate(), time) }
                    pickDate = false
                }) { Text(stringResource(R.string.common_ok)) }
            },
            dismissButton = { TextButton(onClick = { pickDate = false }) { Text(stringResource(R.string.common_cancel)) } },
        ) { DatePicker(state) }
    }
    if (pickTime) {
        val state = rememberTimePickerState(time.hour, time.minute, is24Hour = true)
        AlertDialog(
            onDismissRequest = { pickTime = false },
            confirmButton = {
                TextButton(onClick = {
                    set(date ?: today.plusDays(1), LocalTime.of(state.hour, state.minute))
                    pickTime = false
                }) { Text(stringResource(R.string.common_ok)) }
            },
            dismissButton = { TextButton(onClick = { pickTime = false }) { Text(stringResource(R.string.common_cancel)) } },
            text = { TimePicker(state) },
        )
    }
}

@Composable
private fun PickerRow(@StringRes label: Int, value: String?, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = DevetTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
        Text(stringResource(label), style = DevetTheme.type.footnote, color = c.textSecondary)
        Row(
            modifier.fillMaxWidth().heightIn(min = Sizes.controlHeight).background(c.bgSunken, Shapes.control)
                .border(1.dp, c.borderControl, Shapes.control)
                .selectable(false, role = Role.Button, onClick = onClick).padding(horizontal = Spacing.s2),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(value.orEmpty(), style = DevetTheme.type.body, color = if (value == null) c.textSecondary else c.textPrimary, modifier = Modifier.weight(1f))
            Icon(DevetIcons.chevronRight, contentDescription = null, tint = c.textSecondary)
        }
    }
}

@Composable
fun VenueFields(draft: EventDraft, onChange: ((EventDraft) -> EventDraft) -> Unit, showRequired: Boolean) {
    val c = DevetTheme.colors
    val clipboard = LocalClipboardManager.current
    val status = mapStatus(draft.mapsUrl)
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        DevetTextField(
            draft.venueName, { v -> onChange { it.copy(venueName = v.take(EventRules.MAX_VENUE)) } }, R.string.create_venue, DevetIcons.globe,
            isError = showRequired && draft.venueName.isBlank(), modifier = Modifier.testTag("venueName"),
        )
        DevetTextField(
            draft.venueAddress, { v -> onChange { it.copy(venueAddress = v) } }, R.string.create_address, DevetIcons.globe,
            supporting = stringResource(R.string.create_address_hint), modifier = Modifier.testTag("venueAddress"),
        )
        DevetTextField(
            draft.mapsUrl, { v -> onChange { it.copy(mapsUrl = v) } }, R.string.create_map_link, DevetIcons.globe,
            keyboardType = KeyboardType.Uri, isError = status == MapStatus.Invalid,
            supporting = stringResource(if (status == MapStatus.Invalid) R.string.create_map_invalid else R.string.create_map_help),
            modifier = Modifier.testTag("mapsUrl"),
        )
        LinkButton(stringResource(R.string.create_paste), {
            clipboard.getText()?.text?.let { pasted -> onChange { it.copy(mapsUrl = pasted.trim()) } }
        })
        when (status) {
            MapStatus.CoordsFound -> Strip(stringResource(R.string.create_coords_ok), c.feedbackSuccessBg, c.feedbackSuccess, DevetIcons.check)
            MapStatus.NoCoords -> Strip(stringResource(R.string.create_no_coords), c.feedbackWarningBg, c.feedbackWarning, DevetIcons.alert)
            else -> Unit
        }
    }
}

@Composable
private fun Strip(text: String, bg: androidx.compose.ui.graphics.Color, fg: androidx.compose.ui.graphics.Color, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Row(
        Modifier.fillMaxWidth().background(bg, Shapes.control).padding(Spacing.s1_5).testTag("mapStatus"),
        horizontalArrangement = Arrangement.spacedBy(Spacing.s1),
    ) {
        Icon(icon, contentDescription = null, tint = fg, modifier = Modifier.size(20.dp))
        Text(text, style = DevetTheme.type.callout, color = fg)
    }
}

@Composable
fun LanguageChoices(selected: String, onSelect: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1_5)) {
        AppLanguage.SUPPORTED.forEach { lang ->
            ChoiceCard(stringResource(LANGUAGE_NAMES.getValue(lang)), selected == lang, { onSelect(lang) }, Modifier.testTag("lang_$lang"))
        }
        Text(stringResource(R.string.create_lang_help), style = DevetTheme.type.callout, color = DevetTheme.colors.textSecondary)
    }
}

/** Toggle + mini preview of the guest page's table block, on and off (screens.md §3 step 6). */
@Composable
fun TablematesToggle(on: Boolean, onChange: (Boolean) -> Unit) {
    val c = DevetTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
        Row(
            Modifier.fillMaxWidth().background(c.bgSurface, Shapes.card).toggleable(on, role = Role.Switch, onValueChange = onChange)
                .padding(Spacing.s2).testTag("tablemates"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
                Text(stringResource(R.string.create_tablemates), style = DevetTheme.type.headline, color = c.textPrimary)
                Text(stringResource(R.string.create_tablemates_help), style = DevetTheme.type.footnote, color = c.textSecondary)
            }
            Switch(
                checked = on, onCheckedChange = null,
                colors = SwitchDefaults.colors(checkedTrackColor = c.brandPrimary, checkedThumbColor = c.textOnBrand, uncheckedBorderColor = c.borderControl),
            )
        }
        Text(stringResource(R.string.create_preview_label), style = DevetTheme.type.caption, color = c.textSecondary)
        Column(
            Modifier.fillMaxWidth().background(c.bgSurface, Shapes.card).border(1.dp, c.accentGold, Shapes.card).padding(Spacing.s2),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.s0_5),
        ) {
            Text(stringResource(R.string.create_your_table), style = DevetTheme.type.footnote, color = c.textSecondary)
            Text("12", style = DevetTheme.type.serifTitle, color = c.brandPrimary)
            Text(
                stringResource(if (on) R.string.create_mates else R.string.create_mates_off),
                style = DevetTheme.type.callout, color = if (on) c.textPrimary else c.textSecondary,
            )
        }
    }
}
