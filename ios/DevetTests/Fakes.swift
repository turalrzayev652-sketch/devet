import Foundation
@testable import Devet

final class FakeAuth: AuthRepository, @unchecked Sendable {
    var currentEmail: String? = "aysel@example.com"
    var calls: [String] = []

    var signInResult: Result<Void, AuthFailure> = .success(())
    var signUpResult: Result<Bool, AuthFailure> = .success(true)
    var resetResult: Result<Void, AuthFailure> = .success(())
    var exchangeResult: Result<Void, AuthFailure> = .success(())
    var updateResult: Result<Void, AuthFailure> = .success(())

    func sessionStates() -> AsyncStream<SessionState> { AsyncStream { $0.yield(.signedOut) } }
    func signIn(email: String, password: String) async -> Result<Void, AuthFailure> { calls.append("signIn:\(email)"); return signInResult }
    func signUp(name: String, email: String, password: String) async -> Result<Bool, AuthFailure> { calls.append("signUp:\(name):\(email)"); return signUpResult }
    func resendConfirmation(email: String) async -> Result<Void, AuthFailure> { calls.append("resend:\(email)"); return .success(()) }
    func sendPasswordReset(email: String) async -> Result<Void, AuthFailure> { calls.append("reset:\(email)"); return resetResult }
    func exchangeCode(_ code: String) async -> Result<Void, AuthFailure> { calls.append("exchange:\(code)"); return exchangeResult }
    func updatePassword(_ password: String) async -> Result<Void, AuthFailure> { calls.append("update"); return updateResult }
    func signOut() async { calls.append("signOut") }
}

final class FakeAccount: AccountRepository, @unchecked Sendable {
    var calls: [String] = []
    var profileResult: Result<Profile, AuthFailure> = .success(Profile(id: "u1", email: "aysel@example.com", displayName: "Aysel", uiLang: "az"))
    var deleteResult: Result<Void, AuthFailure> = .success(())

    func profile() async -> Result<Profile, AuthFailure> { profileResult }
    func updateName(_ name: String) async -> Result<Void, AuthFailure> { calls.append("name:\(name)"); return .success(()) }
    func updateLanguage(_ lang: String) async -> Result<Void, AuthFailure> { calls.append("lang:\(lang)"); return .success(()) }
    func deleteAccount() async -> Result<Void, AuthFailure> { calls.append("delete"); return deleteResult }
}

struct FakeLanguage: AppLanguage {
    var effective = "ru"
    func openSystemSettings() {}
}
