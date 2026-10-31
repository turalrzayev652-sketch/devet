import SwiftUI

/// Pushed screens of the sign-in flow (spec/screens.md §1).
enum AuthRoute: Hashable {
    case register, confirmEmail(String), resetPassword, resetSent
}

/// Pushed screens inside the app. Filled in module by module (T43+).
enum AppRoute: Hashable {
    case settings
    case createEvent
    case editEvent(String)
    /// Inside an event: guests [6] (T45/T46).
    case eventHome(id: String, title: String)
    case templates(eventId: String)
    case joinByCode
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
    /// Bumped by create/edit so the list reloads when it comes back.
    @State private var reload = 0

    var body: some View {
        NavigationStack(path: $path) {
            EventsView(
                vm: EventsViewModel(repo: deps.events, archive: deps.archive), reloadToken: reload,
                onSettings: { path.append(.settings) },
                onOpen: { path.append(.eventHome(id: $0.id, title: $0.titleNames)) },
                onCreate: { path.append(.createEvent) },
                onEdit: { path.append(.editEvent($0.id)) },
                onJoin: { path.append(.joinByCode) }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .settings:
                    SettingsView(
                        vm: SettingsViewModel(account: deps.account, auth: deps.auth, language: deps.language),
                        termsURL: deps.termsURL, privacyURL: deps.privacyURL
                    )
                case .createEvent:
                    CreateEventView(
                        vm: CreateEventViewModel(repo: deps.events, language: deps.language),
                        onClose: { path.removeLast() },
                        onCreated: { reload += 1 },
                        onChooseTemplate: { path = [.templates(eventId: $0)] }
                    )
                case let .editEvent(id):
                    EditEventView(vm: EditEventViewModel(repo: deps.events, eventId: id), onSaved: {
                        reload += 1
                        path.removeLast()
                    })
                case let .eventHome(_, title):
                    ComingSoonView(title: Text(verbatim: title))
                case .templates:
                    ComingSoonView(title: Text("create.success.choose_template"))
                case .joinByCode:
                    ComingSoonView(title: Text("events.join"))
                }
            }
        }
    }
}
