import XCTest
@testable import Devet

/// Same cases as Android `AuthRulesTest` (parity rule).
final class AuthRulesTests: XCTestCase {
    func testEmailFormat() {
        for v in ["a@b.c", "aysel.mammadova@example.com", "  x@y.az "] { XCTAssertTrue(AuthValidation.isEmail(v), v) }
        for v in ["", "a@b", "@b.c", "a b@c.d", "a@b c.d", "ab.c"] { XCTAssertFalse(AuthValidation.isEmail(v), v) }
    }

    func testPasswordAtLeastSix() {
        XCTAssertFalse(AuthValidation.isPassword("12345"))
        XCTAssertTrue(AuthValidation.isPassword("123456"))
    }

    func testRegisterNeedsEveryField() {
        XCTAssertTrue(AuthValidation.canRegister(name: "Aysel", email: "a@b.c", password: "secret1", repeat: "secret1", termsAccepted: true))
        XCTAssertFalse(AuthValidation.canRegister(name: " ", email: "a@b.c", password: "secret1", repeat: "secret1", termsAccepted: true))
        XCTAssertFalse(AuthValidation.canRegister(name: "Aysel", email: "a@b", password: "secret1", repeat: "secret1", termsAccepted: true))
        XCTAssertFalse(AuthValidation.canRegister(name: "Aysel", email: "a@b.c", password: "12345", repeat: "12345", termsAccepted: true))
        XCTAssertFalse(AuthValidation.canRegister(name: "Aysel", email: "a@b.c", password: "secret1", repeat: "secret2", termsAccepted: true))
        XCTAssertFalse(AuthValidation.canRegister(name: "Aysel", email: "a@b.c", password: "secret1", repeat: "secret1", termsAccepted: false))
        XCTAssertFalse(AuthValidation.canRegister(name: String(repeating: "x", count: 81), email: "a@b.c", password: "secret1", repeat: "secret1", termsAccepted: true))
    }

    func testSignInNeedsEmailAndAnyPassword() {
        XCTAssertTrue(AuthValidation.canSignIn(email: "a@b.c", password: "1"))
        XCTAssertFalse(AuthValidation.canSignIn(email: "a@b.c", password: ""))
    }

    func testErrorCodesFromSupabaseAuth() {
        XCTAssertEqual(AuthFailure.fromCode("invalid_credentials"), .invalidCredentials)
        XCTAssertEqual(AuthFailure.fromCode("email_not_confirmed"), .emailNotConfirmed)
        XCTAssertEqual(AuthFailure.fromCode("user_already_exists"), .userAlreadyExists)
        XCTAssertEqual(AuthFailure.fromCode("weak_password"), .weakPassword)
        XCTAssertEqual(AuthFailure.fromCode("over_email_send_rate_limit"), .rateLimited)
        XCTAssertEqual(AuthFailure.fromCode("otp_expired"), .linkInvalid)
        XCTAssertEqual(AuthFailure.fromCode("something_new"), .unknown)
        XCTAssertEqual(AuthFailure.fromCode(nil), .unknown)
        XCTAssertEqual(AuthFailure.from(URLError(.notConnectedToInternet)), .network)
    }

    func testDeepLinks() {
        XCTAssertEqual(AuthDeepLink.parse(URL(string: "az.devet.app://auth/reset-password?code=abc-123")),
                       AuthDeepLink(kind: .recovery, code: "abc-123", errorCode: nil))
        XCTAssertEqual(AuthDeepLink.parse(URL(string: "az.devet.app://auth/callback?code=c0de")),
                       AuthDeepLink(kind: .confirm, code: "c0de", errorCode: nil))
        // Expired link: GoTrue puts the error in the fragment.
        let expired = AuthDeepLink.parse(URL(string: "az.devet.app://auth/callback#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid"))
        XCTAssertEqual(expired?.errorCode, "otp_expired")
        XCTAssertNil(expired?.code)
        XCTAssertNil(AuthDeepLink.parse(URL(string: "https://example.com/auth/callback?code=x")))
        XCTAssertNil(AuthDeepLink.parse(URL(string: "az.devet.app://auth/other?code=x")))
        XCTAssertNil(AuthDeepLink.parse(nil))
    }

    func testRootScreenFollowsSession() {
        XCTAssertEqual(rootFor(.loading, recovery: false), .splash)
        XCTAssertEqual(rootFor(.signedOut, recovery: false), .signIn)
        XCTAssertEqual(rootFor(.signedIn, recovery: false), .events)
        XCTAssertEqual(rootFor(.signedIn, recovery: true), .newPassword)
        // Recovery flag set before the code exchange finishes: stay on sign-in until the session arrives.
        XCTAssertEqual(rootFor(.signedOut, recovery: true), .signIn)
    }
}
