import Supabase
import XCTest
@testable import Devet

/// Stubbed HTTP for the real supabase-swift client (the iOS counterpart of Android's MockEngine test).
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
            request.httpBody = data
        }
        Self.requests.append(request)
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil,
                // GoTrue answers in the 2024-01-01 error format when the client sends that API version (supabase-swift does).
                headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// In-memory session store so tests never touch the Keychain.
final class MemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { values[key] = value }
    func retrieve(key: String) throws -> Data? { values[key] }
    func remove(key: String) throws { values[key] = nil }
}

/// Checks the SDK error → `AuthFailure` mapping and the request shape against canned GoTrue answers.
final class SupabaseAuthRepositoryTests: XCTestCase {
    private func repo(_ handler: @escaping (URLRequest) throws -> (Int, String)) -> SupabaseAuthRepository {
        StubProtocol.handler = handler
        StubProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let client = makeDevetSupabase(
            SupabaseConfig(url: "https://test.supabase.co", anonKey: "anon-key", publicBaseURL: ""),
            session: URLSession(configuration: configuration), storage: MemoryStorage()
        )
        return SupabaseAuthRepository(client: client)
    }

    private func error(_ status: Int, _ code: String) -> (Int, String) { (status, #"{"code":"\#(code)","message":"\#(code)"}"#) }

    private func user(_ identities: String) -> String {
        #"{"id":"11111111-1111-1111-1111-111111111111","aud":"authenticated","role":"authenticated","email":"aysel@example.com","app_metadata":{},"user_metadata":{"display_name":"Aysel"},"identities":\#(identities),"created_at":"2026-10-31T10:00:00Z","updated_at":"2026-10-31T10:00:00Z"}"#
    }

    private var lastRequest: URLRequest { StubProtocol.requests.last! }
    private func query(_ name: String) -> String? {
        URLComponents(url: lastRequest.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    func testWrongPassword() async {
        let r = await repo { _ in self.error(400, "invalid_credentials") }.signIn(email: "aysel@example.com", password: "nope")
        XCTAssertEqual(r.failure, .invalidCredentials)
        XCTAssertTrue(lastRequest.url!.path.hasSuffix("/auth/v1/token"))
    }

    func testUnconfirmedEmail() async {
        let r = await repo { _ in self.error(400, "email_not_confirmed") }.signIn(email: "aysel@example.com", password: "secret1")
        XCTAssertEqual(r.failure, .emailNotConfirmed)
    }

    func testNetworkFailure() async {
        let r = await repo { _ in throw URLError(.notConnectedToInternet) }.signIn(email: "aysel@example.com", password: "secret1")
        XCTAssertEqual(r.failure, .network)
    }

    func testSignUpSendsNameAndRedirect() async throws {
        let identity = #"[{"identity_id":"22222222-2222-2222-2222-222222222222","id":"x","user_id":"11111111-1111-1111-1111-111111111111","provider":"email","identity_data":{},"created_at":"2026-10-31T10:00:00Z","last_sign_in_at":"2026-10-31T10:00:00Z","updated_at":"2026-10-31T10:00:00Z"}]"#
        let r = await repo { _ in (200, self.user(identity)) }.signUp(name: " Aysel ", email: " aysel@example.com ", password: "secret1")
        XCTAssertEqual(try r.get(), true, "confirmation needed (no session)")
        XCTAssertTrue(lastRequest.url!.path.hasSuffix("/auth/v1/signup"))
        XCTAssertEqual(query("redirect_to"), AuthDeepLink.confirmURL.absoluteString)
        let body = String(data: lastRequest.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains(#""display_name":"Aysel""#) && body.contains(#""email":"aysel@example.com""#), body)
    }

    func testSignUpExistingEmailWithConfirmationsOn() async {
        let r = await repo { _ in (200, self.user("[]")) }.signUp(name: "Aysel", email: "aysel@example.com", password: "secret1")
        XCTAssertEqual(r.failure, .userAlreadyExists)
    }

    func testSignUpExistingEmailWithConfirmationsOff() async {
        let r = await repo { _ in self.error(422, "user_already_exists") }.signUp(name: "Aysel", email: "aysel@example.com", password: "secret1")
        XCTAssertEqual(r.failure, .userAlreadyExists)
    }

    func testWeakPassword() async {
        let body = #"{"code":"weak_password","message":"weak","weak_password":{"reasons":["length"]}}"#
        let r = await repo { _ in (422, body) }.signUp(name: "Aysel", email: "aysel@example.com", password: "123456")
        XCTAssertEqual(r.failure, .weakPassword)
    }

    func testResetUsesRecoveryLink() async {
        let r = await repo { _ in (200, "{}") }.sendPasswordReset(email: "aysel@example.com")
        XCTAssertNil(r.failure)
        XCTAssertTrue(lastRequest.url!.path.hasSuffix("/auth/v1/recover"))
        XCTAssertEqual(query("redirect_to"), AuthDeepLink.recoveryURL.absoluteString)
    }

    func testRateLimitedResend() async {
        let r = await repo { _ in self.error(429, "over_email_send_rate_limit") }.resendConfirmation(email: "aysel@example.com")
        XCTAssertEqual(r.failure, .rateLimited)
    }

    func testWithoutSettingsEverythingFailsSoftly() async {
        let r = await SupabaseAuthRepository(client: nil).signIn(email: "a@b.c", password: "secret1")
        XCTAssertEqual(r.failure, .notConfigured)
    }
}

extension Result {
    var failure: Failure? {
        if case let .failure(e) = self { return e }
        return nil
    }
}
