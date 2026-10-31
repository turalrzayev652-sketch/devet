package az.devet.app.ui.components

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import az.devet.app.R
import az.devet.app.data.auth.AuthError
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Sizes
import az.devet.app.ui.theme.Spacing

/** User-visible message for an error (spec/api.md §0.2). */
@StringRes
fun AuthError.messageRes(): Int = when (this) {
    AuthError.InvalidCredentials -> R.string.auth_error_invalid_credentials
    AuthError.UserAlreadyExists -> R.string.auth_error_email_taken
    AuthError.WeakPassword -> R.string.auth_error_weak_password
    AuthError.RateLimited -> R.string.auth_error_rate_limited
    AuthError.LinkInvalid -> R.string.auth_error_link_invalid
    AuthError.Network -> R.string.common_error_network
    AuthError.Forbidden -> R.string.common_error_forbidden
    AuthError.EmailNotConfirmed, AuthError.Unauthorized, AuthError.NotConfigured, AuthError.Unknown -> R.string.common_error_unknown
}

@Composable
fun DevetTextField(
    value: String,
    onValueChange: (String) -> Unit,
    @StringRes label: Int,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Next,
    onIme: () -> Unit = {},
    isError: Boolean = false,
    supporting: String? = null,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    readOnly: Boolean = false,
    trailing: @Composable (() -> Unit)? = null,
) {
    val c = DevetTheme.colors
    OutlinedTextField(
        readOnly = readOnly,
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        label = { Text(stringResource(label)) },
        leadingIcon = { Icon(icon, contentDescription = null) },
        trailingIcon = trailing,
        singleLine = true,
        isError = isError,
        supportingText = supporting?.let { text ->
            {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s0_5), verticalAlignment = Alignment.CenterVertically) {
                    if (isError) Icon(DevetIcons.alert, contentDescription = null, modifier = Modifier.size(16.dp))
                    Text(text, modifier = Modifier.semantics { if (isError) liveRegion = LiveRegionMode.Polite })
                }
            }
        },
        textStyle = DevetTheme.type.body,
        shape = Shapes.control,
        visualTransformation = visualTransformation,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
        keyboardActions = KeyboardActions(onAny = { onIme() }),
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = c.bgSurface, unfocusedContainerColor = c.bgSunken, errorContainerColor = c.bgSurface,
            focusedBorderColor = c.borderFocus, unfocusedBorderColor = c.borderControl, errorBorderColor = c.feedbackDanger,
            focusedLeadingIconColor = c.textSecondary, unfocusedLeadingIconColor = c.textSecondary,
            errorSupportingTextColor = c.feedbackDanger, unfocusedSupportingTextColor = c.textSecondary,
            focusedSupportingTextColor = c.textSecondary,
        ),
    )
}

@Composable
fun PasswordField(
    value: String,
    onValueChange: (String) -> Unit,
    @StringRes label: Int,
    modifier: Modifier = Modifier,
    imeAction: ImeAction = ImeAction.Done,
    onIme: () -> Unit = {},
    isError: Boolean = false,
    supporting: String? = null,
) {
    var visible by rememberSaveable { mutableStateOf(false) }
    DevetTextField(
        value = value, onValueChange = onValueChange, label = label, icon = DevetIcons.lock, modifier = modifier,
        keyboardType = KeyboardType.Password, imeAction = imeAction, onIme = onIme, isError = isError, supporting = supporting,
        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
        trailing = {
            IconButton(onClick = { visible = !visible }) {
                Icon(
                    if (visible) DevetIcons.eyeOff else DevetIcons.eye,
                    contentDescription = stringResource(if (visible) R.string.auth_password_hide else R.string.auth_password_show),
                )
            }
        },
    )
}

/** Main action: brand fill, 52 pt, spinner inside while loading (screens.md §1). */
@Composable
fun PrimaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, loading: Boolean = false) {
    val c = DevetTheme.colors
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier.fillMaxWidth().heightIn(min = Sizes.controlHeight),
        shape = Shapes.control,
        colors = ButtonDefaults.buttonColors(
            containerColor = c.brandPrimary, contentColor = c.textOnBrand,
            disabledContainerColor = if (loading) c.brandPrimary else c.bgSunken,
            disabledContentColor = if (loading) c.textOnBrand else c.textSecondary,
        ),
    ) {
        if (loading) CircularProgressIndicator(Modifier.size(22.dp), color = c.textOnBrand, strokeWidth = 2.dp)
        else Text(text, style = DevetTheme.type.headline)
    }
}

@Composable
fun LinkButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    TextButton(onClick = onClick, modifier = modifier.heightIn(min = Sizes.touchMin)) {
        Text(text, style = DevetTheme.type.headline, color = DevetTheme.colors.textLink)
    }
}

@Composable
fun BackButton(onClick: () -> Unit) {
    IconButton(onClick = onClick, modifier = Modifier.size(Sizes.touchMin)) {
        Icon(DevetIcons.back, contentDescription = stringResource(R.string.common_back), tint = DevetTheme.colors.textPrimary)
    }
}

/** Offline strip at the top (screens.md: offline → strip, main action disabled). */
@Composable
fun OfflineBanner(modifier: Modifier = Modifier) {
    val c = DevetTheme.colors
    Row(
        modifier.fillMaxWidth().background(c.feedbackWarningBg).padding(horizontal = Spacing.gutter, vertical = Spacing.s1_5).testTag("offline"),
        horizontalArrangement = Arrangement.spacedBy(Spacing.s1),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(DevetIcons.wifiOff, contentDescription = null, tint = c.feedbackWarning, modifier = Modifier.size(20.dp))
        Text(stringResource(R.string.common_error_network), style = DevetTheme.type.callout, color = c.feedbackWarning)
    }
}

/** Error strip inside a form (danger background, icon + text). */
@Composable
fun ErrorBanner(text: String, modifier: Modifier = Modifier) {
    val c = DevetTheme.colors
    Row(
        modifier.fillMaxWidth().background(c.feedbackDangerBg, Shapes.control).padding(Spacing.s1_5)
            .semantics { liveRegion = LiveRegionMode.Polite },
        horizontalArrangement = Arrangement.spacedBy(Spacing.s1),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(DevetIcons.alert, contentDescription = null, tint = c.feedbackDanger, modifier = Modifier.size(20.dp))
        Text(text, style = DevetTheme.type.callout, color = c.feedbackDanger)
    }
}

/** Art + serif title + body + actions ("check your e-mail" screens). */
@Composable
fun MessageContent(title: String, body: String, modifier: Modifier = Modifier, actions: @Composable () -> Unit) {
    val c = DevetTheme.colors
    Column(
        modifier.fillMaxWidth().padding(top = Spacing.s6),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.s1_5),
    ) {
        Box(Modifier.padding(bottom = Spacing.s1)) {
            Icon(DevetIcons.envelope, contentDescription = null, tint = c.accentGold, modifier = Modifier.size(160.dp, 124.dp))
        }
        Text(title, style = DevetTheme.type.serifHeadline, color = c.textPrimary)
        Text(body, style = DevetTheme.type.body, color = c.textSecondary, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Box(Modifier.padding(top = Spacing.s2)) { Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) { actions() } }
    }
}
