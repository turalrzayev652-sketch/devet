package az.devet.app.ui.guests

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import az.devet.app.R
import az.devet.app.data.AppLanguage
import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.DevetTextField
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Sizes
import az.devet.app.ui.theme.Spacing

// Fields of the guest form (screens.md §6.1), used by manual add (§7a) and later by guest edit (T46).

@StringRes
fun Salutation.label() = when (this) {
    Salutation.Muellim -> R.string.guest_salutation_muellim
    Salutation.Xanim -> R.string.guest_salutation_xanim
    Salutation.Bey -> R.string.guest_salutation_bey
    Salutation.None -> R.string.guest_salutation_none
}

@StringRes
fun Side.label() = when (this) {
    Side.Groom -> R.string.guest_side_groom
    Side.Bride -> R.string.guest_side_bride
    Side.None -> R.string.guest_side_none
}

private val LANGUAGE_NAMES = mapOf("az" to R.string.lang_az, "ru" to R.string.lang_ru, "en" to R.string.lang_en, "tr" to R.string.lang_tr)

/** One selectable segment / chip. */
@Composable
fun Chip(text: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val c = DevetTheme.colors
    Text(
        text, style = DevetTheme.type.callout, color = if (selected) c.brandPrimary else c.textPrimary, textAlign = TextAlign.Center,
        modifier = modifier.heightIn(min = Sizes.chipHeight).background(if (selected) c.brandSubtle else c.bgSurface, Shapes.pill)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.brandPrimary else c.borderHairline, Shapes.pill)
            .selectable(selected, role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = Spacing.s1_5, vertical = Spacing.s1),
    )
}

@Composable
fun FieldLabel(@StringRes text: Int) {
    Text(stringResource(text), style = DevetTheme.type.footnote, color = DevetTheme.colors.textSecondary)
}

@Composable
fun SalutationPicker(value: Salutation, onChange: (Salutation) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
        FieldLabel(R.string.guest_salutation)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1), modifier = Modifier.horizontalScroll(rememberScrollState())) {
            Salutation.entries.forEach { s -> Chip(stringResource(s.label()), value == s, { onChange(s) }, Modifier.testTag("sal_${s.key}")) }
        }
    }
}

@Composable
fun SidePicker(value: Side, onChange: (Side) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
        FieldLabel(R.string.guest_side)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1), modifier = Modifier.horizontalScroll(rememberScrollState())) {
            Side.entries.forEach { s -> Chip(stringResource(s.label()), value == s, { onChange(s) }) }
        }
    }
}

@Composable
fun LangPicker(value: String?, onChange: (String?) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
        FieldLabel(R.string.guest_lang)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s1), modifier = Modifier.horizontalScroll(rememberScrollState())) {
            Chip(stringResource(R.string.guest_lang_event), value == null, { onChange(null) })
            AppLanguage.SUPPORTED.forEach { l -> Chip(stringResource(LANGUAGE_NAMES.getValue(l)), value == l, { onChange(l) }) }
        }
    }
}

/** − n + for invited people (1–50). */
@Composable
fun CountStepper(value: Int, onChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    val c = DevetTheme.colors
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Text(stringResource(R.string.guest_count), style = DevetTheme.type.body, color = c.textPrimary, modifier = Modifier.weight(1f))
        IconButton(onClick = { onChange(value - 1) }, enabled = value > 1) { Text("−", style = DevetTheme.type.title2, color = c.textPrimary) }
        Text(value.toString(), style = DevetTheme.type.headline, color = c.textPrimary, textAlign = TextAlign.Center, modifier = Modifier.widthIn(min = 32.dp).testTag("count"))
        IconButton(onClick = { onChange(value + 1) }, enabled = value < 50) { Text("+", style = DevetTheme.type.title2, color = c.textPrimary) }
    }
}

@Composable
fun FamilySwitch(value: Boolean, onChange: (Boolean) -> Unit) {
    val c = DevetTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = Sizes.touchMin).toggleable(value, role = Role.Switch, onValueChange = onChange),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(stringResource(R.string.guest_with_family), style = DevetTheme.type.body, color = c.textPrimary, modifier = Modifier.weight(1f))
        Switch(value, onCheckedChange = null, colors = SwitchDefaults.colors(checkedTrackColor = c.brandPrimary, checkedThumbColor = c.textOnBrand))
    }
}

/** "Dəvətnamədə belə görünəcək" — greeting in the guest's language (screens.md §6.1). */
@Composable
fun GreetingPreview(names: DisplayNames, form: GuestForm, eventLang: String) {
    val c = DevetTheme.colors
    if (form.name.isBlank()) return
    Column(
        Modifier.fillMaxWidth().background(c.bgSurface, Shapes.card).border(1.dp, c.accentGold, Shapes.card).padding(Spacing.s2),
        verticalArrangement = Arrangement.spacedBy(Spacing.s0_5),
    ) {
        Text(stringResource(R.string.guest_preview), style = DevetTheme.type.caption, color = c.textSecondary)
        Text(
            names.greeting(form.name, form.salutation, form.withFamily, form.lang ?: eventLang),
            style = DevetTheme.type.serifHeadline, color = c.textPrimary, modifier = Modifier.testTag("greeting"),
        )
    }
}

@Composable
fun PhoneField(value: String, onChange: (String) -> Unit, issue: PhoneIssue, duplicateOf: String?) {
    val c = DevetTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s0_5)) {
        DevetTextField(
            value, onChange, R.string.guest_phone, DevetIcons.phone, keyboardType = KeyboardType.Phone,
            isError = issue != PhoneIssue.None,
            supporting = when (issue) {
                PhoneIssue.Invalid -> stringResource(R.string.phone_error_invalid)
                PhoneIssue.NotMobile -> stringResource(R.string.phone_error_not_mobile)
                PhoneIssue.None -> "+994"
            },
            modifier = Modifier.testTag("phone"),
        )
        if (duplicateOf != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s0_5), verticalAlignment = Alignment.CenterVertically) {
                Icon(DevetIcons.alert, null, tint = c.feedbackWarning, modifier = Modifier.size(16.dp))
                Text(stringResource(R.string.guest_duplicate, duplicateOf), style = DevetTheme.type.footnote, color = c.feedbackWarning)
            }
        }
    }
}
