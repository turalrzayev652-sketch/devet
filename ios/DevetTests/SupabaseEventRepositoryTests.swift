import XCTest
@testable import Devet

/// Real supabase-swift PostgREST against canned answers: request shape (api.md §2 [2], [3]) and RLS outcomes.
/// Same cases as Android `SupabaseEventRepositoryTest`.
final class SupabaseEventRepositoryTests: XCTestCase {
    private func repo(_ status: Int = 200, _ body: String = "[]") -> SupabaseEventRepository {
        StubProtocol.handler = { _ in (status, body) }
        StubProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let client = makeDevetSupabase(
            SupabaseConfig(url: "https://test.supabase.co", anonKey: "anon-key", publicBaseURL: ""),
            session: URLSession(configuration: configuration), storage: MemoryStorage()
        )
        return SupabaseEventRepository(client: client)
    }

    private var last: URLRequest { StubProtocol.requests.last! }
    private func query(_ name: String) -> String? {
        URLComponents(url: last.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
    private var bodyText: String { String(data: last.httpBody ?? Data(), encoding: .utf8) ?? "" }
    private let start = ISO8601DateFormatter().date(from: "2027-07-12T14:00:00Z")!

    func testListParsesRoleAndStats() async throws {
        let body = #"[{"id":"e1","type":"engagement","title_names":"Aysel və Ramin","starts_at":"2027-07-12T14:00:00+00:00","venue_name":"Ağ Saray","template_id":null,"status":"draft","templates":null,"event_members":[{"user_id":"other","role":"owner"}],"guests":[{"rsvp_status":"yes","rsvp_count":3},{"rsvp_status":"yes","rsvp_count":2},{"rsvp_status":"pending","rsvp_count":0},{"rsvp_status":"no","rsvp_count":0}]}]"#
        let e = try await repo(200, body).list().get().first!
        XCTAssertEqual(e.type, .engagement)
        XCTAssertEqual(e.startsAt, start)
        XCTAssertEqual(e.guestCount, 4)
        XCTAssertEqual(e.comingPeople, 5, "people coming")
        XCTAssertEqual(e.noAnswer, 1)
        XCTAssertEqual(e.role, .owner)
        XCTAssertTrue(last.url!.path.hasSuffix("/rest/v1/events"))
        XCTAssertTrue(query("select")!.contains("guests(rsvp_status,rsvp_count"))
        XCTAssertTrue(query("order")!.hasPrefix("starts_at.asc"))
    }

    func testCreateSendsColumnsWithoutCreatedBy() async throws {
        let draft = EventDraft(type: .wedding, titleNames: "Aysel və Ramin", startsAt: start, venueName: "Ağ Saray",
                               mapsURL: "https://maps.google.com/?q=40.4093,49.8671")
        let id = try await repo(201, #"{"id":"new"}"#).create(draft).get()
        XCTAssertEqual(id, "new")
        XCTAssertEqual(last.httpMethod, "POST")
        XCTAssertTrue(bodyText.contains(#""starts_at":"2027-07-12T18:00+04:00""#) && bodyText.contains(#""venue_lat":40.4093"#), bodyText)
        XCTAssertFalse(bodyText.contains("created_by"))
        XCTAssertTrue((last.value(forHTTPHeaderField: "Prefer") ?? "").contains("return=representation"))
    }

    func testCohostDeleteGetsZeroRows() async {
        let r = await repo(200, "[]").delete("e1")
        XCTAssertEqual(r.failure, .forbidden)
        XCTAssertEqual(last.httpMethod, "DELETE")
        XCTAssertEqual(query("id"), "eq.e1")
    }

    func testOwnerDelete() async {
        let r = await repo(200, #"[{"id":"e1"}]"#).delete("e1")
        XCTAssertNil(r.failure)
    }

    func testUpdateSendsOnlyChanges() async {
        let before = EventDraft(type: .wedding, titleNames: "A", startsAt: start, venueName: "Hall")
        var after = before; after.showTablemates = true
        let r = await repo(200, #"[{"id":"e1"}]"#).update("e1", before: before, after: after)
        XCTAssertNil(r.failure)
        XCTAssertEqual(bodyText, #"{"show_tablemates":true}"#)
        let none = repo()
        let r2 = await none.update("e1", before: before, after: before)
        XCTAssertNil(r2.failure)
        XCTAssertTrue(StubProtocol.requests.isEmpty, "no change → no request")
    }

    func testRlsInsertRefusal() async {
        let body = #"{"code":"42501","details":null,"hint":null,"message":"new row violates row-level security policy"}"#
        let r = await repo(403, body).create(EventDraft(type: .wedding))
        XCTAssertEqual(r.failure, .forbidden)
    }
}
