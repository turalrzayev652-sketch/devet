import Foundation

// Successful sign-in / sign-up changes the session; AppModel then opens the app. These view models only hold
// form state, loading and errors (spec/screens.md §1). Same behaviour as the Android view models.

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = "" { didSet { error = nil } }
    @Published var password = "" { didSet { error = nil } }
    @Published private(set) var loading = false
    @Published private(set) var error: AuthFailure?
    /// Set when the account exists but the e-mail is not confirmed → confirmation screen.
    @Published var unconfirmedEmail: String?

    private let auth: any AuthRepository
    init(auth: any AuthRepository) { self.auth = auth }

    var canSubmit: Bool { AuthValidation.canSignIn(email: email, password: password) && !loading }

    func submit() async {
        guard canSubmit else { return }
        loading = true
        let result = await auth.signIn(email: email, password: password)
        loading = false
        switch result {
        case .success: password = ""
        case .failure(.emailNotConfirmed): unconfirmedEmail = email.trimmed
        case let .failure(e): error = e
        }
    }
}

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name = "" { didSet { if name.count > AuthValidation.maxName { name = String(name.prefix(AuthValidation.maxName)) }; error = nil } }
    @Published var email = "" { didSet { error = nil } }
    @Published var password = "" { didSet { error = nil } }
    @Published var repeatPassword = "" { didSet { error = nil } }
    @Published var termsAccepted = false
    @Published private(set) var loading = false
    @Published private(set) var error: AuthFailure?
    /// Set after sign-up when a confirmation e-mail was sent.
    @Published var confirmationSentTo: String?

    private let auth: any AuthRepository
    init(auth: any AuthRepository) { self.auth = auth }

    var canSubmit: Bool {
        AuthValidation.canRegister(name: name, email: email, password: password, repeat: repeatPassword, termsAccepted: termsAccepted) && !loading
    }
    var passwordMismatch: Bool { AuthValidation.mismatch(password, repeatPassword) }
    /// Everything else is valid — the only missing step is the terms checkbox.
    var termsMissing: Bool {
        !termsAccepted && AuthValidation.canRegister(name: name, email: email, password: password, repeat: repeatPassword, termsAccepted: true)
    }

    func submit() async {
        guard canSubmit else { return }
        loading = true
        let result = await auth.signUp(name: name, email: email, password: password)
        loading = false
        switch result {
        case let .success(sent): if sent { confirmationSentTo = email.trimmed }
        case let .failure(e): error = e
        }
    }
}

@MainActor
final class ConfirmEmailViewModel: ObservableObject {
    @Published private(set) var sending = false
    @Published private(set) var sent = false
    @Published private(set) var error: AuthFailure?

    private let auth: any AuthRepository
    init(auth: any AuthRepository) { self.auth = auth }

    func resend(_ email: String) async {
        guard !sending else { return }
        sending = true; sent = false; error = nil
        let result = await auth.resendConfirmation(email: email)
        sending = false
        switch result {
        case .success: sent = true
        case let .failure(e): error = e
        }
    }
}

@MainActor
final class ResetPasswordViewModel: ObservableObject {
    @Published var email = "" { didSet { error = nil } }
    @Published private(set) var loading = false
    @Published private(set) var error: AuthFailure?
    @Published var sent = false

    private let auth: any AuthRepository
    init(auth: any AuthRepository) { self.auth = auth }

    var canSubmit: Bool { AuthValidation.isEmail(email) && !loading }

    func submit() async {
        guard canSubmit else { return }
        loading = true
        let result = await auth.sendPasswordReset(email: email)
        loading = false
        switch result {
        // Only transport errors are shown; anything else still says "check your e-mail" (no account probing).
        case let .failure(e) where e == .network || e == .rateLimited || e == .notConfigured: error = e
        default: sent = true
        }
    }
}

@MainActor
final class NewPasswordViewModel: ObservableObject {
    @Published var password = "" { didSet { error = nil } }
    @Published var repeatPassword = "" { didSet { error = nil } }
    @Published private(set) var loading = false
    @Published private(set) var error: AuthFailure?
    @Published private(set) var done = false

    private let auth: any AuthRepository
    init(auth: any AuthRepository) { self.auth = auth }

    var canSubmit: Bool { AuthValidation.canSetPassword(password, repeat: repeatPassword) && !loading }
    var passwordMismatch: Bool { AuthValidation.mismatch(password, repeatPassword) }

    func submit() async {
        guard canSubmit else { return }
        loading = true
        let result = await auth.updatePassword(password)
        loading = false
        switch result {
        case .success: done = true
        case let .failure(e): error = e
        }
    }
}
