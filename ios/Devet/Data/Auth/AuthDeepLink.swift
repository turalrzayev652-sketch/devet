import Foundation

/// Links from Supabase Auth e-mails (custom scheme, decision 2026-10-31; spec/api.md §2 [1]):
/// - `az.devet.app://auth/callback?code=…` — sign-up confirmation;
/// - `az.devet.app://auth/reset-password?code=…` — password recovery.
/// PKCE: the code is exchanged for a session. Errors arrive as `error_code` in the query or fragment.
struct AuthDeepLink: Equatable {
    enum Kind { case confirm, recovery }

    let kind: Kind
    let code: String?
    let errorCode: String?

    static let scheme = "az.devet.app"
    static let host = "auth"
    static let confirmURL = URL(string: "\(scheme)://\(host)/callback")!
    static let recoveryURL = URL(string: "\(scheme)://\(host)/reset-password")!

    static func parse(_ url: URL?) -> AuthDeepLink? {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == scheme, parts.host == host else { return nil }
        let kind: Kind
        switch parts.path.hasSuffix("/") ? String(parts.path.dropLast()) : parts.path {
        case "/callback": kind = .confirm
        case "/reset-password": kind = .recovery
        default: return nil
        }
        var params: [String: String] = [:]
        for item in parts.queryItems ?? [] { params[item.name] = item.value ?? "" }
        if let fragment = parts.fragment, let items = URLComponents(string: "?" + fragment)?.queryItems {
            for item in items { params[item.name] = item.value ?? "" }
        }
        let code = params["code"].flatMap { $0.isEmpty ? nil : $0 }
        return AuthDeepLink(kind: kind, code: code, errorCode: params["error_code"] ?? params["error"])
    }
}
