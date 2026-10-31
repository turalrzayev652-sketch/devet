import Foundation
import Supabase

/// Auth error categories from spec/api.md §0.2 and §2 [1]. Same set as Android `AuthError` (parity rule).
/// Named `AuthFailure` because supabase-swift already has `AuthError`.
enum AuthFailure: Error, Equatable {
    case invalidCredentials
    case emailNotConfirmed
    case userAlreadyExists
    case weakPassword
    case rateLimited
    case linkInvalid
    case unauthorized
    /// RLS refused the change (PostgREST 42501, 403, or 0 rows updated/deleted).
    case forbidden
    case network
    /// Build has no Supabase settings (Secrets.xcconfig); only happens in development.
    case notConfigured
    case unknown

    /// Maps a Supabase Auth `error_code` (GoTrue) to a category.
    static func fromCode(_ code: String?) -> AuthFailure {
        switch code {
        case "invalid_credentials": .invalidCredentials
        case "email_not_confirmed": .emailNotConfirmed
        case "user_already_exists", "email_exists": .userAlreadyExists
        case "weak_password": .weakPassword
        case "over_email_send_rate_limit", "over_request_rate_limit": .rateLimited
        case "otp_expired", "flow_state_expired", "flow_state_not_found", "bad_code_verifier", "access_denied": .linkInvalid
        case "session_not_found", "session_expired", "refresh_token_not_found", "no_authorization": .unauthorized
        default: .unknown
        }
    }

    /// Any error from a backend call → category.
    static func from(_ error: Error) -> AuthFailure {
        switch error {
        case let failure as AuthFailure:
            return failure
        case let auth as AuthError:
            if case .pkceGrantCodeExchange = auth { return .linkInvalid }
            let mapped = fromCode(auth.errorCode.rawValue)
            if mapped == .unknown, case let .api(_, _, _, response) = auth, response.statusCode == 401 { return .unauthorized }
            return mapped
        case let postgrest as PostgrestError:
            return postgrest.code == "42501" ? .forbidden : postgrest.code == "PGRST301" ? .unauthorized : .unknown
        case let functions as FunctionsError:
            if case let .httpError(code, _) = functions, code == 401 { return .unauthorized }
            return .unknown
        case is URLError:
            return .network
        default:
            let ns = error as NSError
            return ns.domain == NSURLErrorDomain ? .network : .unknown
        }
    }
}

/// Runs a backend call and turns any failure into an `AuthFailure`.
func runAuth<T>(_ block: () async throws -> T) async -> Result<T, AuthFailure> {
    do {
        return .success(try await block())
    } catch {
        return .failure(AuthFailure.from(error))
    }
}
