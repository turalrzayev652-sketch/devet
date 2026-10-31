import Foundation
import Supabase

enum SessionState: Equatable { case loading, signedIn, signedOut }

/// Supabase Auth calls for screen [1] (spec/api.md §2 [1]). The SDK keeps (Keychain) and refreshes the session itself.
protocol AuthRepository: Sendable {
    /// Current state first, then every change.
    func sessionStates() -> AsyncStream<SessionState>
    var currentEmail: String? { get }

    func signIn(email: String, password: String) async -> Result<Void, AuthFailure>
    /// `true` — confirmation e-mail sent; `false` — signed in straight away (confirmations off).
    func signUp(name: String, email: String, password: String) async -> Result<Bool, AuthFailure>
    func resendConfirmation(email: String) async -> Result<Void, AuthFailure>
    /// Succeeds for unknown e-mails too — account existence is not revealed (screens.md §1).
    func sendPasswordReset(email: String) async -> Result<Void, AuthFailure>
    /// PKCE code from an e-mail link → session.
    func exchangeCode(_ code: String) async -> Result<Void, AuthFailure>
    func updatePassword(_ password: String) async -> Result<Void, AuthFailure>
    func signOut() async
}

/// `client` is nil when the build has no Supabase settings: the app starts signed out and every call fails softly.
final class SupabaseAuthRepository: AuthRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func sessionStates() -> AsyncStream<SessionState> {
        guard let client else {
            return AsyncStream { $0.yield(.signedOut); $0.finish() }
        }
        return AsyncStream { continuation in
            continuation.yield(.loading)
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    switch event {
                    case .signedOut, .userDeleted: continuation.yield(.signedOut)
                    // A stored session (even with an expired token) keeps the user in; the SDK refreshes it.
                    default: continuation.yield(session == nil ? .signedOut : .signedIn)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    var currentEmail: String? { client?.auth.currentUser?.email }

    func signIn(email: String, password: String) async -> Result<Void, AuthFailure> {
        await call { client in
            _ = try await client.auth.signIn(email: email.trimmed, password: password)
        }
    }

    func signUp(name: String, email: String, password: String) async -> Result<Bool, AuthFailure> {
        await call { client in
            let response = try await client.auth.signUp(
                email: email.trimmed, password: password,
                data: ["display_name": .string(name.trimmed)], redirectTo: AuthDeepLink.confirmURL
            )
            // With confirmations on, GoTrue answers an existing e-mail with an obfuscated user without identities.
            if response.session == nil, response.user.identities?.isEmpty == true { throw AuthFailure.userAlreadyExists }
            return response.session == nil
        }
    }

    func resendConfirmation(email: String) async -> Result<Void, AuthFailure> {
        await call { client in
            try await client.auth.resend(email: email.trimmed, type: .signup, emailRedirectTo: AuthDeepLink.confirmURL)
        }
    }

    func sendPasswordReset(email: String) async -> Result<Void, AuthFailure> {
        await call { client in
            try await client.auth.resetPasswordForEmail(email.trimmed, redirectTo: AuthDeepLink.recoveryURL)
        }
    }

    func exchangeCode(_ code: String) async -> Result<Void, AuthFailure> {
        await call { client in
            _ = try await client.auth.exchangeCodeForSession(authCode: code)
        }
    }

    func updatePassword(_ password: String) async -> Result<Void, AuthFailure> {
        await call { client in
            _ = try await client.auth.update(user: UserAttributes(password: password))
        }
    }

    func signOut() async {
        _ = await call { client in try await client.auth.signOut() }
    }

    private func call<T>(_ block: (SupabaseClient) async throws -> T) async -> Result<T, AuthFailure> {
        guard let client else { return .failure(.notConfigured) }
        return await runAuth { try await block(client) }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
