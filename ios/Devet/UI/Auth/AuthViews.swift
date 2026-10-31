import SwiftUI

/// Formats a catalog string with positional arguments (`{email}` → `%1$@` in the generated catalog).
func localized(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

/// Canvas background, keyboard-aware scrolling column with the screen gutter, optional offline strip.
struct AuthScaffold<Content: View>: View {
    var offline = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if offline { OfflineBanner() }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s2) { content }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.vertical, Spacing.s2)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Brand: View {
    private let brandName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            BotanicalArt().frame(height: 150)
            Text(brandName.prefix(1))
                .devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.brandPrimary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.DS.bgSurface))
                .overlay(Circle().stroke(Color.DS.accentGold, lineWidth: 1))
                .offset(y: -40)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(brandName).devetFont(DevetType.serifDisplay).foregroundStyle(Color.DS.textPrimary)
                Text("app.welcome").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary).accessibilityIdentifier("welcome")
            }
            .offset(y: -28)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, -28)
    }
}

private struct ScreenTitle: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        Text(title).devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary)
        if let subtitle { Text(subtitle).devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary) }
    }
}

/// "Question? Link" row under a form.
private struct SwitchRow: View {
    let question: LocalizedStringKey
    let link: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: Spacing.s1) { parts }
            VStack(spacing: 0) { parts }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var parts: some View {
        Text(question).devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary)
        LinkButton(title: link, action: action)
    }
}

// MARK: - [1] Sign in

struct SignInView: View {
    @StateObject var vm: SignInViewModel
    @ObservedObject var connectivity: Connectivity
    let onRegister: () -> Void
    let onForgot: () -> Void
    let onUnconfirmed: (String) -> Void

    var body: some View {
        let credentialsError = vm.error == .invalidCredentials
        AuthScaffold(offline: !connectivity.isOnline) {
            Brand()
            DevetTextField(label: "auth.email", icon: DevetIcon.mail, text: $vm.email, keyboard: .emailAddress, contentType: .username, isError: credentialsError)
            DevetTextField(
                label: "auth.password", icon: DevetIcon.lock, text: $vm.password, contentType: .password, secure: true,
                isError: credentialsError, supporting: credentialsError ? "auth.error.invalid_credentials" : nil,
                submitLabel: .go, onSubmit: { Task { await vm.submit() } }
            )
            if let error = vm.error, !credentialsError { ErrorBanner(message: error.messageKey) }
            PrimaryButton(title: "auth.login.button", enabled: vm.canSubmit && connectivity.isOnline, loading: vm.loading) {
                Task { await vm.submit() }
            }
            .accessibilityIdentifier("signIn")
            LinkButton(title: "auth.forgot", action: onForgot).frame(maxWidth: .infinity)
            HStack(spacing: Spacing.s1_5) {
                Rectangle().fill(Color.DS.borderHairline).frame(height: 1)
                Text("auth.or").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                Rectangle().fill(Color.DS.borderHairline).frame(height: 1)
            }
            SwitchRow(question: "auth.no_account", link: "auth.register.link", action: onRegister)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: vm.unconfirmedEmail) { email in
            if let email { onUnconfirmed(email); vm.unconfirmedEmail = nil }
        }
    }
}

// MARK: - Registration

struct RegisterView: View {
    @StateObject var vm: RegisterViewModel
    @ObservedObject var connectivity: Connectivity
    let termsURL: URL?
    let privacyURL: URL?
    let onSignIn: () -> Void
    let onConfirmationSent: (String) -> Void
    @State private var emailTouched = false

    var body: some View {
        let emailInvalid = emailTouched && !vm.email.trimmed.isEmpty && !AuthValidation.isEmail(vm.email)
        let emailTaken = vm.error == .userAlreadyExists
        AuthScaffold(offline: !connectivity.isOnline) {
            ScreenTitle(title: "auth.register.title")
            DevetTextField(label: "auth.name", icon: DevetIcon.user, text: $vm.name, contentType: .name)
            DevetTextField(
                label: "auth.email", icon: DevetIcon.mail, text: $vm.email, keyboard: .emailAddress, contentType: .username,
                isError: emailInvalid || emailTaken,
                supporting: emailTaken ? "auth.error.email_taken" : emailInvalid ? "auth.error.invalid_email" : nil,
                onFocusChange: { focused in if !focused && !vm.email.isEmpty { emailTouched = true } }
            )
            DevetTextField(
                label: "auth.password", icon: DevetIcon.lock, text: $vm.password, contentType: .newPassword, secure: true,
                isError: vm.error == .weakPassword, supporting: vm.error == .weakPassword ? "auth.error.weak_password" : "auth.password.help"
            )
            DevetTextField(
                label: "auth.password_repeat", icon: DevetIcon.lock, text: $vm.repeatPassword, contentType: .newPassword, secure: true,
                isError: vm.passwordMismatch, supporting: vm.passwordMismatch ? "auth.error.password_mismatch" : nil, submitLabel: .done
            )
            TermsRow(accepted: $vm.termsAccepted, termsURL: termsURL, privacyURL: privacyURL)
            if vm.termsMissing {
                Text("auth.error.terms_required").devetFont(DevetType.footnote).foregroundStyle(Color.DS.feedbackWarning)
            }
            if let error = vm.error, !emailTaken, error != .weakPassword { ErrorBanner(message: error.messageKey) }
            PrimaryButton(title: "auth.register.button", enabled: vm.canSubmit && connectivity.isOnline, loading: vm.loading) {
                Task { await vm.submit() }
            }
            .accessibilityIdentifier("register")
            SwitchRow(question: "auth.have_account", link: "auth.login.link", action: onSignIn)
        }
        .onChange(of: vm.confirmationSentTo) { email in
            if let email { onConfirmationSent(email); vm.confirmationSentTo = nil }
        }
    }
}

/// Checkbox + "I agree to the {terms} and {privacy}" with both parts as links (spec/screens.md §1).
private struct TermsRow: View {
    @Binding var accepted: Bool
    let termsURL: URL?
    let privacyURL: URL?

    private var text: AttributedString {
        let template = localized("auth.terms.agree", "\u{1}T", "\u{1}P")
        var result = AttributedString()
        var rest = Substring(template)
        while let i = rest.firstIndex(of: "\u{1}") {
            result += AttributedString(String(rest[..<i]))
            let isTerms = rest[rest.index(after: i)] == "T"
            var link = AttributedString(NSLocalizedString(isTerms ? "auth.terms.terms_link" : "auth.terms.privacy_link", comment: ""))
            link.link = isTerms ? termsURL : privacyURL
            link.foregroundColor = Color.DS.textLink
            result += link
            rest = rest[rest.index(i, offsetBy: 2)...]
        }
        result += AttributedString(String(rest))
        return result
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s1_5) {
            Button { accepted.toggle() } label: {
                Image(systemName: accepted ? "checkmark.square.fill" : "square")
                    .font(.title2.weight(.light))
                    .foregroundStyle(accepted ? Color.DS.brandPrimary : Color.DS.borderControl)
                    .frame(width: Sizes.touchMin, height: Sizes.touchMin)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(text))
            .accessibilityAddTraits(accepted ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("terms")
            Text(text).devetFont(DevetType.callout).foregroundStyle(Color.DS.textPrimary).tint(Color.DS.textLink)
        }
    }
}

// MARK: - Confirm e-mail, reset, new password

struct ConfirmEmailView: View {
    let email: String
    @StateObject var vm: ConfirmEmailViewModel
    let onBackToLogin: () -> Void

    var body: some View {
        AuthScaffold {
            MessageContent(title: "auth.confirm.title", body: Text(localized("auth.confirm.body", email))) {
                PrimaryButton(title: "auth.confirm.resend", loading: vm.sending) { Task { await vm.resend(email) } }
                if vm.sent {
                    Text("auth.confirm.resent").devetFont(DevetType.callout).foregroundStyle(Color.DS.feedbackSuccess)
                } else if let error = vm.error {
                    ErrorBanner(message: error.messageKey)
                }
                LinkButton(title: "auth.back_to_login", action: onBackToLogin)
            }
        }
    }
}

struct ResetPasswordView: View {
    @StateObject var vm: ResetPasswordViewModel
    @ObservedObject var connectivity: Connectivity
    let onSent: () -> Void

    var body: some View {
        AuthScaffold(offline: !connectivity.isOnline) {
            ScreenTitle(title: "auth.reset.title", subtitle: "auth.reset.body")
            DevetTextField(
                label: "auth.email", icon: DevetIcon.mail, text: $vm.email, keyboard: .emailAddress, contentType: .username,
                submitLabel: .send, onSubmit: { Task { await vm.submit() } }
            )
            if let error = vm.error { ErrorBanner(message: error.messageKey) }
            PrimaryButton(title: "auth.reset.send", enabled: vm.canSubmit && connectivity.isOnline, loading: vm.loading) {
                Task { await vm.submit() }
            }
        }
        .onChange(of: vm.sent) { sent in if sent { onSent(); vm.sent = false } }
    }
}

struct ResetSentView: View {
    let onBackToLogin: () -> Void

    var body: some View {
        AuthScaffold {
            MessageContent(title: "auth.reset.sent_title", body: Text("auth.reset.sent_body")) {
                PrimaryButton(title: "auth.back_to_login", action: onBackToLogin)
            }
        }
    }
}

struct NewPasswordView: View {
    @StateObject var vm: NewPasswordViewModel
    let onDone: () -> Void

    var body: some View {
        AuthScaffold {
            Spacer().frame(height: Spacing.s3)
            ScreenTitle(title: "auth.new_password.title", subtitle: "auth.new_password.body")
            DevetTextField(
                label: "auth.password", icon: DevetIcon.lock, text: $vm.password, contentType: .newPassword, secure: true,
                isError: vm.error == .weakPassword, supporting: vm.error == .weakPassword ? "auth.error.weak_password" : "auth.password.help"
            )
            DevetTextField(
                label: "auth.password_repeat", icon: DevetIcon.lock, text: $vm.repeatPassword, contentType: .newPassword, secure: true,
                isError: vm.passwordMismatch, supporting: vm.passwordMismatch ? "auth.error.password_mismatch" : nil,
                submitLabel: .done, onSubmit: { Task { await vm.submit() } }
            )
            if let error = vm.error, error != .weakPassword { ErrorBanner(message: error.messageKey) }
            PrimaryButton(title: "auth.new_password.save", enabled: vm.canSubmit, loading: vm.loading) { Task { await vm.submit() } }
        }
        .onChange(of: vm.done) { done in if done { onDone() } }
    }
}
