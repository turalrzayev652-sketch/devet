package az.devet.app.ui.settings

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.BuildConfig
import az.devet.app.R
import az.devet.app.data.AppLanguage
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.DevetTextField
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Sizes
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel

private val LANGUAGE_NAMES = mapOf("az" to R.string.lang_az, "ru" to R.string.lang_ru, "en" to R.string.lang_en, "tr" to R.string.lang_tr)

/** Screen [12b] Settings (spec/screens.md §12b). */
@Composable
fun SettingsScreen(termsUrl: String, privacyUrl: String, onBack: () -> Unit, vm: SettingsViewModel = koinViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors
    val uri = LocalUriHandler.current
    Column(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding()) {
        Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.gutter, vertical = Spacing.s1),
            verticalArrangement = Arrangement.spacedBy(Spacing.s3),
        ) {
            Text(stringResource(R.string.settings_title), style = DevetTheme.type.serifDisplay, color = c.textPrimary)
            if (s.error != null) ErrorBanner(stringResource(s.error!!.messageRes()))

            Section(R.string.settings_profile) {
                DevetTextField(
                    s.name, vm::onName, R.string.settings_name, DevetIcons.user, onIme = vm::saveName,
                    supporting = if (s.saved) stringResource(R.string.settings_saved) else null,
                    modifier = Modifier.testTag("name"),
                )
                DevetTextField(
                    s.email, {}, R.string.auth_email, DevetIcons.mail, keyboardType = KeyboardType.Email,
                    modifier = Modifier.testTag("email"), readOnly = true,
                )
                PrimaryButton(stringResource(R.string.common_save), vm::saveName, enabled = s.canSaveName, loading = s.saving)
            }

            Section(R.string.settings_language) {
                Card {
                    LanguageRow(stringResource(R.string.settings_language_system), s.language == null) { vm.selectLanguage(null) }
                    AppLanguage.SUPPORTED.forEach { lang ->
                        HorizontalDivider(color = c.borderHairline)
                        LanguageRow(stringResource(LANGUAGE_NAMES.getValue(lang)), s.language == lang) { vm.selectLanguage(lang) }
                    }
                }
            }

            Section(R.string.settings_about) {
                Card {
                    LinkRow(stringResource(R.string.settings_terms), DevetIcons.chevronRight) { uri.openUri(termsUrl) }
                    HorizontalDivider(color = c.borderHairline)
                    LinkRow(stringResource(R.string.settings_privacy), DevetIcons.chevronRight) { uri.openUri(privacyUrl) }
                    HorizontalDivider(color = c.borderHairline)
                    Text(
                        stringResource(R.string.settings_version, BuildConfig.VERSION_NAME), style = DevetTheme.type.callout,
                        color = c.textSecondary, modifier = Modifier.padding(Spacing.s2),
                    )
                }
            }

            Card {
                LinkRow(stringResource(R.string.settings_logout), null, Modifier.testTag("logout"), onClick = vm::signOut)
                HorizontalDivider(color = c.borderHairline)
                LinkRow(stringResource(R.string.settings_delete_button), DevetIcons.trash, Modifier.testTag("delete"), c.feedbackDanger, vm::openDelete)
            }
        }
    }

    if (s.deleteDialog) DeleteDialog(s, vm)
}

@Composable
private fun DeleteDialog(s: SettingsState, vm: SettingsViewModel) {
    val c = DevetTheme.colors
    AlertDialog(
        onDismissRequest = { if (!s.deleting) vm.closeDelete() },
        title = { Text(stringResource(R.string.settings_delete_title), style = DevetTheme.type.serifHeadline) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
                Text(stringResource(R.string.settings_delete_body), style = DevetTheme.type.body)
                DevetTextField(
                    s.deleteConfirm, vm::onDeleteConfirm, R.string.settings_delete_confirm_hint, DevetIcons.mail,
                    keyboardType = KeyboardType.Email, modifier = Modifier.testTag("deleteConfirm"),
                )
                if (s.deleteFailed) ErrorBanner(stringResource(R.string.settings_delete_error))
            }
        },
        confirmButton = {
            TextButton(onClick = vm::deleteAccount, enabled = s.canDelete, modifier = Modifier.testTag("deleteConfirmButton")) {
                Text(stringResource(R.string.settings_delete_confirm), color = if (s.canDelete) c.feedbackDanger else c.textSecondary, style = DevetTheme.type.headline)
            }
        },
        dismissButton = {
            TextButton(onClick = vm::closeDelete, enabled = !s.deleting) {
                Text(stringResource(R.string.common_cancel), color = c.textLink, style = DevetTheme.type.headline)
            }
        },
        containerColor = c.bgRaised,
    )
}

@Composable
private fun Section(@StringRes title: Int, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1_5)) {
        Text(stringResource(title).uppercase(), style = DevetTheme.type.caption, color = DevetTheme.colors.textSecondary)
        content()
    }
}

@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().background(DevetTheme.colors.bgSurface, Shapes.card), content = content)
}

@Composable
private fun LanguageRow(name: String, selected: Boolean, onClick: () -> Unit) {
    val c = DevetTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = Sizes.touchMin).selectable(selected, role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(name, style = DevetTheme.type.body, color = c.textPrimary, modifier = Modifier.weight(1f))
        RadioButton(selected = selected, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = c.brandPrimary, unselectedColor = c.borderControl))
    }
}

@Composable
private fun LinkRow(
    text: String,
    icon: ImageVector?,
    modifier: Modifier = Modifier,
    color: Color = DevetTheme.colors.textPrimary,
    onClick: () -> Unit,
) {
    Row(
        modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(onClick = onClick).padding(horizontal = Spacing.s2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, style = DevetTheme.type.body, color = color, modifier = Modifier.weight(1f))
        if (icon != null) Icon(icon, contentDescription = null, tint = if (color == DevetTheme.colors.textPrimary) DevetTheme.colors.textSecondary else color, modifier = Modifier.size(20.dp))
    }
}
