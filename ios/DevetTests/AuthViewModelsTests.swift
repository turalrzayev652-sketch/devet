import XCTest
@testable import Devet

/// Same scenarios as Android `AuthViewModelsTest`.
@MainActor
final class AuthViewModelsTests: XCTestCase {
    private var auth: FakeAuth!

    override func setUp() async throws {
        auth = FakeAuth()
    }

    func testWrongPasswordShowsCredentialsError() async {
        auth.signInResult = .failure(.invalidCredentials)
        let vm = SignInViewModel(auth: auth)
        vm.email = "aysel@example.com"; vm.password = "wrong"
        await vm.submit()
        XCTAssertEqual(vm.error, .invalidCredentials)
        XCTAssertFalse(vm.loading)
        vm.password = "wrong2"
        XCTAssertNil(vm.error, "typing clears the error")
    }

    func testUnconfirmedEmailOpensConfirmation() async {
        auth.signInResult = .failure(.emailNotConfirmed)
        let vm = SignInViewModel(auth: auth)
        vm.email = " aysel@example.com "; vm.password = "secret1"
        await vm.submit()
        XCTAssertEqual(vm.unconfirmedEmail, "aysel@example.com")
        XCTAssertNil(vm.error)
    }

    func testInvalidFormDoesNotCallBackend() async {
        let vm = SignInViewModel(auth: auth)
        vm.email = "not-an-email"; vm.password = "x"
        await vm.submit()
        XCTAssertTrue(auth.calls.isEmpty)
    }

    func testRegisterFlow() async {
        let vm = RegisterViewModel(auth: auth)
        vm.name = "Aysel"; vm.email = "aysel@example.com"; vm.password = "secret1"; vm.repeatPassword = "secret2"
        XCTAssertTrue(vm.passwordMismatch)
        vm.repeatPassword = "secret1"
        XCTAssertFalse(vm.passwordMismatch)
        XCTAssertTrue(vm.termsMissing, "only the checkbox is missing")
        XCTAssertFalse(vm.canSubmit)
        vm.termsAccepted = true
        await vm.submit()
        XCTAssertEqual(auth.calls, ["signUp:Aysel:aysel@example.com"])
        XCTAssertEqual(vm.confirmationSentTo, "aysel@example.com")
    }

    func testRegisterExistingEmail() async {
        auth.signUpResult = .failure(.userAlreadyExists)
        let vm = RegisterViewModel(auth: auth)
        vm.name = "Aysel"; vm.email = "aysel@example.com"; vm.password = "secret1"; vm.repeatPassword = "secret1"; vm.termsAccepted = true
        await vm.submit()
        XCTAssertEqual(vm.error, .userAlreadyExists)
        XCTAssertNil(vm.confirmationSentTo)
    }

    func testResetNeverRevealsAccounts() async {
        auth.resetResult = .failure(.unknown)
        let vm = ResetPasswordViewModel(auth: auth)
        vm.email = "nobody@example.com"
        await vm.submit()
        XCTAssertTrue(vm.sent)

        auth.resetResult = .failure(.network)
        let offline = ResetPasswordViewModel(auth: auth)
        offline.email = "aysel@example.com"
        await offline.submit()
        XCTAssertFalse(offline.sent)
        XCTAssertEqual(offline.error, .network)
    }

    func testNewPasswordNeedsMatchingSixChars() async {
        let vm = NewPasswordViewModel(auth: auth)
        vm.password = "12345"; vm.repeatPassword = "12345"
        XCTAssertFalse(vm.canSubmit)
        vm.password = "123456"; vm.repeatPassword = "123456"
        await vm.submit()
        XCTAssertTrue(vm.done)
    }

    func testRecoveryLinkOpensNewPassword() async throws {
        let app = AppModel(auth: auth)
        app.handleLink(URL(string: "az.devet.app://auth/reset-password?code=k1"))
        XCTAssertTrue(app.recovery, "set before the exchange")
        try await waitUntil { !auth.calls.isEmpty }
        XCTAssertEqual(auth.calls, ["exchange:k1"])
        app.passwordUpdated()
        XCTAssertFalse(app.recovery)
        XCTAssertEqual(app.message, .passwordUpdated)
    }

    func testBadLinksShowAMessage() async throws {
        let app = AppModel(auth: auth)
        app.handleLink(URL(string: "az.devet.app://auth/callback#error_code=otp_expired"))
        XCTAssertEqual(app.message, .linkInvalid)
        XCTAssertTrue(auth.calls.isEmpty)

        app.message = nil
        auth.exchangeResult = .failure(.linkInvalid)
        app.handleLink(URL(string: "az.devet.app://auth/reset-password?code=used"))
        try await waitUntil { app.message != nil }
        XCTAssertFalse(app.recovery, "failed exchange leaves recovery")
        XCTAssertEqual(app.message, .linkInvalid)

        app.message = nil
        app.handleLink(URL(string: "https://example.com/"))
        XCTAssertNil(app.message, "foreign links are ignored")
    }

    func testSettingsDeleteNeedsTypedEmail() async {
        let account = FakeAccount()
        let vm = SettingsViewModel(account: account, auth: auth, language: FakeLanguage())
        await vm.load()
        XCTAssertEqual(vm.name, "Aysel")
        vm.openDelete()
        vm.deleteConfirm = "other@example.com"
        XCTAssertFalse(vm.canDelete)
        vm.deleteConfirm = " AYSEL@example.com "
        XCTAssertTrue(vm.canDelete)
        await vm.deleteAccount()
        XCTAssertTrue(account.calls.contains("delete"))
        XCTAssertTrue(auth.calls.contains("signOut"), "signed out after deletion")
    }

    func testSettingsDeleteFailureKeepsSession() async {
        let account = FakeAccount()
        account.deleteResult = .failure(.unknown)
        let vm = SettingsViewModel(account: account, auth: auth, language: FakeLanguage())
        await vm.load()
        vm.openDelete(); vm.deleteConfirm = "aysel@example.com"
        await vm.deleteAccount()
        XCTAssertTrue(vm.deleteFailed)
        XCTAssertFalse(auth.calls.contains("signOut"))
    }

    func testSettingsSyncsLanguageAndSavesName() async {
        let account = FakeAccount()
        let vm = SettingsViewModel(account: account, auth: auth, language: FakeLanguage(effective: "ru"))
        await vm.load()
        XCTAssertEqual(account.calls, ["lang:ru"], "profile says az, UI shows ru → ui_lang follows the UI")
        XCTAssertFalse(vm.canSaveName, "unchanged name")
        vm.name = " Aysel Məmmədova "
        await vm.saveName()
        XCTAssertEqual(account.calls.last, "name:Aysel Məmmədova")
        XCTAssertTrue(vm.saved)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(nanoseconds: 10_000_000) }
    }
}
