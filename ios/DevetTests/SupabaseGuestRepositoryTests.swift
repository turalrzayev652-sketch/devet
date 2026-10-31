import XCTest
@testable import Devet

/// Real supabase-swift against canned PostgREST answers: batch insert shape and the limit trigger (api.md §2 [7], §5).
/// Same cases as Android `SupabaseGuestRepositoryTest`.
final class SupabaseGuestRepositoryTests: XCTestCase {
    private func repo(_ status: Int, _ body: String) -> SupabaseGuestRepository {
        StubProtocol.handler = { _ in (status, body) }
        StubProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return SupabaseGuestRepository(client: makeDevetSupabase(
            SupabaseConfig(url: "https://test.supabase.co", anonKey: "anon-key", publicBaseURL: ""),
            session: URLSession(configuration: configuration), storage: MemoryStorage()
        ))
    }

    private let two = [
        NewGuest(name: "Elçin", salutation: .muellim, withFamily: true, invitedCount: 4, phoneE164: "+994501234567", side: .groom, tableNo: "12"),
        NewGuest(name: "Leyla"),
    ]

    func testBatchInsertIsOneRequestWithoutServerColumns() async {
        let r = await repo(201, #"[{"id":"a"},{"id":"b"}]"#).add("e1", two)
        XCTAssertEqual(r, .added(2))
        XCTAssertEqual(StubProtocol.requests.count, 1)
        let req = StubProtocol.requests[0]
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertTrue(req.url!.path.hasSuffix("/rest/v1/guests"))
        let body = String(data: req.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.hasPrefix("[") && body.contains(#""event_id":"e1""#) && body.contains(#""salutation":"muellim""#), body)
        XCTAssertTrue(body.contains(#""phone_e164":null"#) && body.contains(#""lang":null"#), body)
        XCTAssertFalse(body.contains(#""code""#), "code is server-only")
        XCTAssertFalse(body.contains("added_by"), "added_by defaults to auth.uid()")
    }

    func testLimitTriggerRefusesTheWholeBatch() async {
        let body = #"{"code":"P0001","details":"limit=100","hint":"purchase_required","message":"guest_limit_exceeded"}"#
        let r = await repo(400, body).add("e1", two)
        XCTAssertEqual(r, .limitExceeded(100))
    }

    func testRlsRefusal() async {
        let body = #"{"code":"42501","details":null,"hint":null,"message":"new row violates row-level security policy"}"#
        let r = await repo(403, body).add("e1", two)
        XCTAssertEqual(r, .failed(.forbidden))
    }
}
