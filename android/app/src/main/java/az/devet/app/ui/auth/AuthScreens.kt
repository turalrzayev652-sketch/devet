package az.devet.app.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthValidation
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.DevetTextField
import az.devet.app.ui.components.ErrorBanner
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.MessageContent
import az.devet.app.ui.components.OfflineBanner
import az.devet.app.ui.components.PasswordField
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.components.messageRes
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel

/** Canvas background, safe area, keyboard-aware scrolling column with the screen gutter. */
@Composable
private fun AuthScaffold(
    offline: Boolean = false,
    onBack: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize().background(DevetTheme.colors.bgCanvas).safeDrawingPadding().imePadding()) {
        if (offline) OfflineBanner()
        if (onBack != null) Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
        Column(
            Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.gutter, vertical = Spacing.s2),
            verticalArrangement = Arrangement.spacedBy(Spacing.s2),
            content = content,
        )
    }
}

@Composable
private fun Brand() {
    val c = DevetTheme.colors
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(DevetIcons.botanical, contentDescription = null, tint = c.accentGold, modifier = Modifier.fillMaxWidth().height(150.dp))
        Box(
            Modifier.offset(y = (-40).dp).size(64.dp).background(c.bgSurface, CircleShape).border(1.dp, c.accentGold, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(stringResource(R.string.app_name).take(1), style = DevetTheme.type.serifTitle, color = c.brandPrimary)
        }
        Column(Modifier.offset(y = (-28).dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(stringResource(R.string.app_name), style = DevetTheme.type.serifDisplay, color = c.textPrimary)
            Text(stringResource(R.string.app_welcome), style = DevetTheme.type.serifHeadline, color = c.textPrimary, modifier = Modifier.testTag("welcome"))
        }
    }
}

@Composable
private fun Title(text: String, body: String? = null) {
    Text(text, style = DevetTheme.type.serifTitle, color = DevetTheme.colors.textPrimary)
    if (body != null) Text(body, style = DevetTheme.type.body, color = DevetTheme.colors.textSecondary)
}

/** "Question? Link" row under a form. */
@Composable
private fun SwitchRow(question: String, link: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Text(question, style = DevetTheme.type.body, color = DevetTheme.colors.textSecondary)
        LinkButton(link, onClick)
    }
}

// ---------------------------------------------------------------------------------------------------------------
// [1] Sign in
// ---------------------------------------------------------------------------------------------------------------

@Composable
fun SignInScreen(onRegister: () -> Unit, onForgot: () -> Unit, onUnconfirmed: (String) -> Unit, vm: SignInViewModel = koinViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val online by vm.online.collectAsStateWithLifecycle()
    LaunchedEffect(s.unconfirmedEmail) {
        s.unconfirmedEmail?.let { onUnconfirmed(it); vm.confirmationShown() }
    }
    val credentialsError = s.error == AuthError.InvalidCredentials
    AuthScaffold(offline = !online) {
        Brand()
        DevetTextField(
            s.email, vm::onEmail, R.string.auth_email, DevetIcons.mail,
            keyboardType = KeyboardType.Email, isError = credentialsError, modifier = Modifier.testTag("email"),
        )
        PasswordField(
            s.password, vm::onPassword, R.string.auth_password, onIme = vm::submit, isError = credentialsError,
            supporting = if (credentialsError) stringResource(R.string.auth_error_invalid_credentials) else null,
            modifier = Modifier.testTag("password"),
        )
        if (s.error != null && !credentialsError) ErrorBanner(stringResource(s.error!!.messageRes()))
        PrimaryButton(
            stringResource(R.string.auth_login_button), vm::submit, enabled = s.canSubmit && online, loading = s.loading,
            modifier = Modifier.testTag("signIn"),
        )
        LinkButton(stringResource(R.string.auth_forgot), onForgot, Modifier.align(Alignment.CenterHorizontally))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1_5)) {
            HorizontalDivider(Modifier.weight(1f), color = DevetTheme.colors.borderHairline)
            Text(stringResource(R.string.auth_or), style = DevetTheme.type.footnote, color = DevetTheme.colors.textSecondary)
            HorizontalDivider(Modifier.weight(1f), color = DevetTheme.colors.borderHairline)
        }
        SwitchRow(stringResource(R.string.auth_no_account), stringResource(R.string.auth_register_link), onRegister)
    }
}

// ---------------------------------------------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------------------------------------------

@Composable
fun RegisterScreen(
    termsUrl: String,
    privacyUrl: String,
    onBack: () -> Unit,
    onConfirmationSent: (String) -> Unit,
    vm: RegisterViewModel = koinViewModel(),
) {
    val s by vm.state.collectAsStateWithLifecycle()
    val online by vm.online.collectAsStateWithLifecycle()
    var emailTouched by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(s.confirmationSentTo) {
        s.confirmationSentTo?.let { onConfirmationSent(it); vm.confirmationShown() }
    }
    val emailInvalid = emailTouched && s.email.isNotBlank() && !AuthValidation.isEmail(s.email)
    val emailTaken = s.error == AuthError.UserAlreadyExists
    AuthScaffold(offline = !online, onBack = onBack) {
        Title(stringResource(R.string.auth_register_title))
        DevetTextField(s.name, vm::onName, R.string.auth_name, DevetIcons.user, modifier = Modifier.testTag("name"))
        DevetTextField(
            s.email, vm::onEmail, R.string.auth_email, DevetIcons.mail, keyboardType = KeyboardType.Email,
            isError = emailInvalid || emailTaken,
            supporting = when {
                emailTaken -> stringResource(R.string.auth_error_email_taken)
                emailInvalid -> stringResource(R.string.auth_error_invalid_email)
                else -> null
            },
            modifier = Modifier.testTag("email").onFocusChanged { if (!it.isFocused && s.email.isNotEmpty()) emailTouched = true },
        )
        PasswordField(
            s.password, vm::onPassword, R.string.auth_password, imeAction = ImeAction.Next,
            isError = s.error == AuthError.WeakPassword,
            supporting = stringResource(if (s.error == AuthError.WeakPassword) R.string.auth_error_weak_password else R.string.auth_password_help),
            modifier = Modifier.testTag("password"),
        )
        PasswordField(
            s.repeat, vm::onRepeat, R.string.auth_password_repeat, isError = s.passwordMismatch,
            supporting = if (s.passwordMismatch) stringResource(R.string.auth_error_password_mismatch) else null,
            modifier = Modifier.testTag("repeat"),
        )
        TermsRow(s.termsAccepted, vm::onTerms, termsUrl, privacyUrl)
        if (s.termsMissing) {
            Text(stringResource(R.string.auth_error_terms_required), style = DevetTheme.type.footnote, color = DevetTheme.colors.feedbackWarning)
        }
        if (s.error != null && !emailTaken && s.error != AuthError.WeakPassword) ErrorBanner(stringResource(s.error!!.messageRes()))
        PrimaryButton(
            stringResource(R.string.auth_register_button), vm::submit, enabled = s.canSubmit && online, loading = s.loading,
            modifier = Modifier.testTag("register"),
        )
        SwitchRow(stringResource(R.string.auth_have_account), stringResource(R.string.auth_login_link), onBack)
    }
}

/** Checkbox + "I agree to the {terms} and {privacy}" with both parts as links (spec/screens.md §1). */
@Composable
private fun TermsRow(checked: Boolean, onChecked: (Boolean) -> Unit, termsUrl: String, privacyUrl: String) {
    val c = DevetTheme.colors
    val template = stringResource(R.string.auth_terms_agree, "\u0000T", "\u0000P")
    val termsText = stringResource(R.string.auth_terms_terms_link)
    val privacyText = stringResource(R.string.auth_terms_privacy_link)
    val linkStyle = TextLinkStyles(SpanStyle(color = c.textLink))
    val text = buildAnnotatedString {
        // Split the translated sentence at the two placeholders so word order stays per language.
        var rest = template
        while (rest.isNotEmpty()) {
            val i = rest.indexOf('\u0000')
            if (i < 0) { append(rest); break }
            append(rest.substring(0, i))
            val isTerms = rest[i + 1] == 'T'
            withLink(LinkAnnotation.Url(if (isTerms) termsUrl else privacyUrl, linkStyle)) { append(if (isTerms) termsText else privacyText) }
            rest = rest.substring(i + 2)
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Checkbox(
            checked = checked, onCheckedChange = onChecked, modifier = Modifier.testTag("terms"),
            colors = CheckboxDefaults.colors(checkedColor = c.brandPrimary, uncheckedColor = c.borderControl, checkmarkColor = c.textOnBrand),
        )
        Text(text, style = DevetTheme.type.callout.copy(color = c.textPrimary))
    }
}

// ---------------------------------------------------------------------------------------------------------------
// Confirm e-mail, reset, new password
// ---------------------------------------------------------------------------------------------------------------

@Composable
fun ConfirmEmailScreen(email: String, onBack: () -> Unit, vm: ConfirmEmailViewModel = koinViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    AuthScaffold(onBack = onBack) {
        MessageContent(stringResource(R.string.auth_confirm_title), stringResource(R.string.auth_confirm_body, email)) {
            PrimaryButton(stringResource(R.string.auth_confirm_resend), { vm.resend(email) }, loading = s.sending, modifier = Modifier.testTag("resend"))
            when {
                s.sent -> Text(stringResource(R.string.auth_confirm_resent), style = DevetTheme.type.callout, color = DevetTheme.colors.feedbackSuccess)
                s.error != null -> ErrorBanner(stringResource(s.error!!.messageRes()))
            }
            LinkButton(stringResource(R.string.auth_back_to_login), onBack, Modifier.align(Alignment.CenterHorizontally))
        }
    }
}

@Composable
fun ResetPasswordScreen(onBack: () -> Unit, onSent: () -> Unit, vm: ResetPasswordViewModel = koinViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    val online by vm.online.collectAsStateWithLifecycle()
    LaunchedEffect(s.sent) { if (s.sent) { onSent(); vm.sentShown() } }
    AuthScaffold(offline = !online, onBack = onBack) {
        Title(stringResource(R.string.auth_reset_title), stringResource(R.string.auth_reset_body))
        DevetTextField(
            s.email, vm::onEmail, R.string.auth_email, DevetIcons.mail, keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Done, onIme = vm::submit, modifier = Modifier.testTag("email"),
        )
        if (s.error != null) ErrorBanner(stringResource(s.error!!.messageRes()))
        PrimaryButton(stringResource(R.string.auth_reset_send), vm::submit, enabled = s.canSubmit && online, loading = s.loading, modifier = Modifier.testTag("send"))
    }
}

@Composable
fun ResetSentScreen(onBackToLogin: () -> Unit) {
    AuthScaffold(onBack = onBackToLogin) {
        MessageContent(stringResource(R.string.auth_reset_sent_title), stringResource(R.string.auth_reset_sent_body)) {
            PrimaryButton(stringResource(R.string.auth_back_to_login), onBackToLogin)
        }
    }
}

@Composable
fun NewPasswordScreen(onDone: () -> Unit, vm: NewPasswordViewModel = koinViewModel()) {
    val s by vm.state.collectAsStateWithLifecycle()
    LaunchedEffect(s.done) { if (s.done) onDone() }
    AuthScaffold {
        Spacer(Modifier.height(Spacing.s3))
        Title(stringResource(R.string.auth_new_password_title), stringResource(R.string.auth_new_password_body))
        PasswordField(
            s.password, vm::onPassword, R.string.auth_password, imeAction = ImeAction.Next,
            isError = s.error == AuthError.WeakPassword,
            supporting = stringResource(if (s.error == AuthError.WeakPassword) R.string.auth_error_weak_password else R.string.auth_password_help),
        )
        PasswordField(
            s.repeat, vm::onRepeat, R.string.auth_password_repeat, onIme = vm::submit, isError = s.passwordMismatch,
            supporting = if (s.passwordMismatch) stringResource(R.string.auth_error_password_mismatch) else null,
        )
        if (s.error != null && s.error != AuthError.WeakPassword) ErrorBanner(stringResource(s.error!!.messageRes()))
        PrimaryButton(stringResource(R.string.auth_new_password_save), vm::submit, enabled = s.canSubmit, loading = s.loading)
    }
}
