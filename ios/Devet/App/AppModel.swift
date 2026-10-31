import Foundation

/// One-off messages shown at the app level (after e-mail links).
enum AppMessage: Equatable { case linkInvalid, network, passwordUpdated }

/// Root screen for the session: sign-in flow when signed out, the app when signed in (screens.md §1).
enum RootScreen: Equatable { case splash, signIn, newPassword, events }

func rootFor(_ session: SessionState, recovery: Bool) -> RootScreen {
    switch session {
    case .loading: .splash
    case .signedIn: recovery ? .newPassword : .events
    case .signedOut: .signIn
    }
}

/// Session and e-mail links (Android `AppViewModel`).
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var session: SessionState = .loading
    /// True while the user must set a new password after a recovery link (the link already signed them in).
    @Published private(set) var recovery = false
    @Published var message: AppMessage?

    private let auth: any AuthRepository
    private var watcher: Task<Void, Never>?

    var root: RootScreen { rootFor(session, recovery: recovery) }

    init(auth: any AuthRepository) {
        self.auth = auth
    }

    func start() {
        guard watcher == nil else { return }
        watcher = Task { [weak self, auth] in
            for await state in auth.sessionStates() { self?.session = state }
        }
    }

    func handleLink(_ url: URL?) {
        guard let link = AuthDeepLink.parse(url) else { return }
        guard link.errorCode == nil, let code = link.code else {
            message = .linkInvalid
            return
        }
        // Set before the exchange: the session appears first and must not open the app instead of the new-password screen.
        if link.kind == .recovery { recovery = true }
        Task {
            if case let .failure(error) = await auth.exchangeCode(code) {
                recovery = false
                message = error == .network ? .network : .linkInvalid
            }
        }
    }

    func passwordUpdated() {
        recovery = false
        message = .passwordUpdated
    }
}
