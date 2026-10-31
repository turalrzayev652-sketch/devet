import SwiftUI

/// Pushed screens of the sign-in flow (spec/screens.md §1).
enum AuthRoute: Hashable {
    case register, confirmEmail(String), resetPassword, resetSent
}

/// Pushed screens inside the app. Filled in module by module (T43+).
enum AppRoute: Hashable {
    case settings
}

/// Root for the session: sign-in flow when signed out, the app when signed in (Android `DevetNavHost`).
struct RootView: View {
    @EnvironmentObject private var deps: AppDependencies
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            Color.DS.bgCanvas.ignoresSafeArea()
            switch app.root {
            case .splash: EmptyView()
            case .signIn: AuthFlow()
            case .newPassword: NewPasswordView(vm: NewPasswordViewModel(auth: deps.auth), onDone: app.passwordUpdated)
            case .events: AppFlow()
            }
            if let message = app.message {
                ToastBanner(message: message.key)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        app.message = nil
                    }
                    .onTapGesture { app.message = nil }
            }
        }
        .tint(Color.DS.brandPrimary)
        .animation(.easeOut(duration: Motion.base), value: app.message)
        .task { app.start() }
        .onOpenURL { app.handleLink($0) }
    }
}

private extension AppMessage {
    var key: LocalizedStringKey {
        switch self {
        case .linkInvalid: "auth.error.link_invalid"
        case .network: "common.error.network"
        case .passwordUpdated: "auth.new_password.done"
        }
    }
}

private struct AuthFlow: View {
    @EnvironmentObject private var deps: AppDependencies
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            SignInView(
                vm: SignInViewModel(auth: deps.auth), connectivity: deps.connectivity,
                onRegister: { path.append(.register) },
                onForgot: { path.append(.resetPassword) },
                onUnconfirmed: { path.append(.confirmEmail($0)) }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .register:
                    RegisterView(
                        vm: RegisterViewModel(auth: deps.auth), connectivity: deps.connectivity,
                        termsURL: deps.termsURL, privacyURL: deps.privacyURL,
                        onSignIn: { path.removeAll() },
                        onConfirmationSent: { path = [.confirmEmail($0)] }
                    )
                case let .confirmEmail(email):
                    ConfirmEmailView(email: email, vm: ConfirmEmailViewModel(auth: deps.auth), onBackToLogin: { path.removeAll() })
                case .resetPassword:
                    ResetPasswordView(vm: ResetPasswordViewModel(auth: deps.auth), connectivity: deps.connectivity, onSent: { path = [.resetSent] })
                case .resetSent:
                    ResetSentView(onBackToLogin: { path.removeAll() })
                }
            }
        }
    }
}

private struct AppFlow: View {
    @EnvironmentObject private var deps: AppDependencies
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            EventsView(onSettings: { path.append(.settings) })
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(
                            vm: SettingsViewModel(account: deps.account, auth: deps.auth, language: deps.language),
                            termsURL: deps.termsURL, privacyURL: deps.privacyURL
                        )
                    }
                }
        }
    }
}
