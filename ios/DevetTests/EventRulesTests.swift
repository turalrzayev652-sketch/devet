import Supabase
import XCTest
@testable import Devet

/// Same cases as Android `EventRulesTest`.
final class EventRulesTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2027-01-10T10:00:00Z")!
    private let start = ISO8601DateFormatter().date(from: "2027-07-12T14:00:00Z")!

    /// Every case of spec/test-vectors/maps.json (shared with Android and the JS reference).
    func testMapsVectors() throws {
        let cases = try XCTUnwrap(try RepoFiles.json("spec/test-vectors/maps.json")["cases"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        for c in cases {
            let input = c["input"] as! String
            let result = MapsLink.parse(input)
            if let error = c["error"] as? String {
                XCTAssertEqual(result, .error(error), input)
                continue
            }
            guard case let .ok(lat, lng) = result else { XCTFail("expected ok for \(input), got \(result)"); continue }
            if let expected = c["expected"] as? [String: Double] {
                XCTAssertEqual(lat ?? .nan, expected["lat"]!, accuracy: 1e-9, input)
                XCTAssertEqual(lng ?? .nan, expected["lng"]!, accuracy: 1e-9, input)
            } else {
                XCTAssertNil(lat, input)
            }
        }
    }

    private var full: EventDraft {
        EventDraft(type: .wedding, titleNames: " Aysel və Ramin ", startsAt: start, venueName: "Ağ Saray",
                   mapsURL: "https://maps.google.com/?q=40.4093,49.8671", defaultLang: "az")
    }

    func testStepRules() {
        XCTAssertFalse(EventRules.stepValid(1, EventDraft(), now: now))
        XCTAssertTrue(EventRules.stepValid(1, full, now: now))
        var d = full; d.titleNames = "  "
        XCTAssertFalse(EventRules.stepValid(2, d, now: now))
        d = full; d.titleNames = String(repeating: "x", count: 81)
        XCTAssertFalse(EventRules.stepValid(2, d, now: now))
        d = full; d.hostNames = String(repeating: "x", count: 121)
        XCTAssertFalse(EventRules.stepValid(2, d, now: now))
        XCTAssertTrue(EventRules.stepValid(2, full, now: now))
        d = full; d.startsAt = now.addingTimeInterval(-60)
        XCTAssertFalse(EventRules.stepValid(3, d, now: now), "past date")
        d = full; d.startsAt = nil
        XCTAssertFalse(EventRules.stepValid(3, d, now: now))
        XCTAssertTrue(EventRules.stepValid(3, full, now: now))
        d = full; d.venueName = ""
        XCTAssertFalse(EventRules.stepValid(4, d, now: now))
        d = full; d.mapsURL = "maps.google.com/?q=1,2"
        XCTAssertFalse(EventRules.stepValid(4, d, now: now), "bad link")
        d = full; d.mapsURL = "https://maps.app.goo.gl/x"
        XCTAssertTrue(EventRules.stepValid(4, d, now: now), "short link is fine")
    }

    func testInsertColumns() {
        let cols = EventRules.columns(full)
        XCTAssertEqual(cols["type"], .string("wedding"))
        XCTAssertEqual(cols["title_names"], .string("Aysel və Ramin"))
        XCTAssertEqual(cols["host_names"], .null)
        XCTAssertEqual(cols["starts_at"], .string("2027-07-12T18:00+04:00"), "same text as Android")
        XCTAssertEqual(cols["venue_lat"], .double(40.4093))
        XCTAssertEqual(cols["venue_lng"], .double(49.8671))
        XCTAssertNil(cols["created_by"], "never sent (api.md §2 [3])")
        XCTAssertNil(cols["status"])
    }

    func testChangedLinkClearsOldCoordinates() {
        var after = full; after.mapsURL = "https://maps.app.goo.gl/x"
        let changes = EventRules.changes(full, after)
        XCTAssertEqual(Set(changes.keys), ["maps_url", "venue_lat", "venue_lng"])
        XCTAssertEqual(changes["venue_lat"], .null)
        XCTAssertTrue(EventRules.changes(full, full).isEmpty)
        after = full; after.showTablemates = true
        XCTAssertEqual(Set(EventRules.changes(full, after).keys), ["show_tablemates"])
    }

    func testArchiveAfterSevenDays() {
        XCTAssertFalse(EventRules.isArchivedByDate(now.addingTimeInterval(-6 * 86400), now: now))
        XCTAssertTrue(EventRules.isArchivedByDate(now.addingTimeInterval(-8 * 86400), now: now))
    }
}
