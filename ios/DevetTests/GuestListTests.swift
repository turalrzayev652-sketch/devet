import XCTest
@testable import Devet

private func guest(_ id: String, _ name: String, side: Side = .none, table: String? = nil, phone: String? = nil,
                   rsvp: String = "pending", sent: Bool = false, opened: Bool = false, count: Int = 0) -> Guest {
    Guest(id: id, code: "C\(id)", salutation: .none, name: name, withFamily: false, invitedCount: 1, phoneE164: phone, side: side, tableNo: table,
          lang: nil, sentAt: sent ? "t" : nil, openedAt: opened ? "t" : nil, rsvpStatus: rsvp, rsvpCount: count)
}

final class FakeGuestList: GuestListRepository, @unchecked Sendable {
    var guests = [
        guest("1", "Elçin", side: .groom, table: "12", phone: "+994501234567", rsvp: "yes", sent: true, count: 4),
        guest("2", "Leyla", side: .bride, table: "7", sent: true, opened: true),
        guest("3", "Rəşad", side: .groom, rsvp: "no", sent: true),
        guest("4", "Nərmin", side: .bride, sent: true),
        guest("5", "Kamran"),
    ]
    var listResult: Result<[Guest], AuthFailure>?
    var limitValue: Int? = 100
    var result: Result<Void, AuthFailure> = .success(())
    var calls: [String] = []
    var lastUpdate: (NewGuest, NewGuest)?

    func list(_ eventId: String) async -> Result<[Guest], AuthFailure> { listResult ?? .success(guests) }
    func limit(_ eventId: String) async -> Result<Int?, AuthFailure> { .success(limitValue) }
    func update(_ id: String, before: NewGuest, after: NewGuest) async -> Result<Void, AuthFailure> { calls.append("update:\(id)"); lastUpdate = (before, after); return result }
    func bulkUpdate(_ ids: [String], column: String, value: String?) async -> Result<Void, AuthFailure> { calls.append("bulk:\(column)=\(value ?? "null"):\(ids.sorted())"); return result }
    func delete(_ ids: [String]) async -> Result<Void, AuthFailure> { calls.append("delete:\(ids.sorted())"); return result }
}

/// Same cases as Android `GuestListTest`.
@MainActor
final class GuestListTests: XCTestCase {
    private var repo: FakeGuestList!
    private var events: FakeEvents!
    private lazy var spec: GuestSpec = {
        func d(_ p: String) -> Data { try! Data(contentsOf: RepoFiles.root.appendingPathComponent(p)) }
        return GuestSpec(excel: try! ExcelRules.from(excel: d("spec/test-vectors/excel.json"), phones: d("spec/test-vectors/phones.json")),
                         displayNames: try! DisplayNames.from(invite: d("spec/i18n/invite.json")))
    }()

    override func setUp() async throws {
        repo = FakeGuestList()
        events = FakeEvents()
        events.getResult = .success(EventDraft(defaultLang: "ru"))
    }

    private func vm(owner: Bool) async -> GuestListViewModel {
        let vm = GuestListViewModel(eventId: "e1", isOwner: owner, repo: repo, events: events, spec: spec)
        await vm.load()
        return vm
    }

    func testStatusFollowsDesignRules() {
        XCTAssertEqual(guest("a", "A", rsvp: "yes").status, .coming)
        XCTAssertEqual(guest("a", "A", rsvp: "no", opened: true).status, .declined)
        XCTAssertEqual(guest("a", "A", sent: true, opened: true).status, .viewed)
        XCTAssertEqual(guest("a", "A", sent: true).status, .pending)
        XCTAssertEqual(guest("a", "A").status, .unsent)
    }

    func testSearchByFoldedNameOrPhoneDigits() {
        let g = guest("1", "Rəşad Əliyev", phone: "+994501234567")
        XCTAssertTrue(searchMatches(g, "resad"))
        XCTAssertTrue(searchMatches(g, "ƏLİYEV"))
        XCTAssertTrue(searchMatches(g, "050 123"))
        XCTAssertFalse(searchMatches(g, "12"))
        XCTAssertFalse(searchMatches(g, "Leyla"))
        XCTAssertTrue(searchMatches(g, "  "))
    }

    func testLimitLevels() {
        XCTAssertEqual(limitLevel(94, 100), .normal)
        XCTAssertEqual(limitLevel(95, 100), .near)
        XCTAssertEqual(limitLevel(100, 100), .full)
        XCTAssertEqual(limitLevel(5, nil), .normal)
    }

    func testOnlyChangedColumnsAreSent() {
        let before = NewGuest(name: "Leyla", salutation: .xanim, phoneE164: "+994551112233", side: .bride, tableNo: "7")
        XCTAssertTrue(guestChanges(before, before).isEmpty)
        var after = before; after.tableNo = "8"; after.invitedCount = 2
        XCTAssertEqual(Set(guestChanges(before, after).keys), ["table_no", "invited_count"])
        after = before; after.tableNo = " "
        XCTAssertEqual(guestChanges(before, after)["table_no"], .null, "blank table becomes null")
    }

    func testFiltersCountsAndSearch() async {
        let vm = await vm(owner: true)
        XCTAssertEqual(vm.limit, 100)
        XCTAssertEqual(vm.eventLang, "ru")
        XCTAssertEqual(vm.count(.all), 5)
        XCTAssertEqual(vm.count(.groom), 2)
        XCTAssertEqual(vm.count(.coming), 1)
        XCTAssertEqual(vm.count(.declined), 1)
        XCTAssertEqual(vm.count(.noAnswer), 2, "viewed + sent without answer")
        XCTAssertEqual(vm.count(.unsent), 1)
        XCTAssertEqual(vm.count(.noTable), 3)
        vm.filter = .bride
        XCTAssertEqual(vm.visible.map(\.name), ["Leyla", "Nərmin"])
        vm.query = "nerm"
        XCTAssertEqual(vm.visible.map(\.name), ["Nərmin"])
    }

    func testEditSavesChangedFieldsAndUpdatesTheRow() async {
        let vm = await vm(owner: false)
        vm.open(vm.guests.first { $0.id == "2" }!)
        vm.edit { $0.table = "9"; $0.salutation = .xanim }
        await vm.saveEdit()
        XCTAssertEqual(repo.calls, ["update:2"])
        XCTAssertEqual(repo.lastUpdate?.1.tableNo, "9")
        XCTAssertEqual(repo.lastUpdate?.0.tableNo, "7")
        XCTAssertNil(vm.editing)
        XCTAssertEqual(vm.message, .saved)
        XCTAssertEqual(vm.guests.first { $0.id == "2" }?.tableNo, "9")
    }

    func testEditRejectsBadPhoneAndEmptyName() async {
        let vm = await vm(owner: true)
        vm.open(vm.guests[0])
        vm.edit { $0.phone = "012 345 67 89" }
        await vm.saveEdit()
        vm.edit { $0.phone = ""; $0.name = "  " }
        await vm.saveEdit()
        XCTAssertTrue(vm.editing?.nameError == true)
        XCTAssertTrue(repo.calls.isEmpty)
    }

    func testCohostCannotDeleteOwnerCan() async {
        let cohost = await vm(owner: false)
        cohost.askDelete(["1"])
        XCTAssertNil(cohost.confirmDelete)

        let owner = await vm(owner: true)
        owner.toggle("1"); owner.toggle("3")
        owner.askDelete(Array(owner.selected))
        await owner.performDelete()
        XCTAssertEqual(repo.calls.last, "delete:[\"1\", \"3\"]")
        XCTAssertEqual(owner.guests.count, 3)
        XCTAssertFalse(owner.selecting)
    }

    func testBulkTableAndSide() async {
        let vm = await vm(owner: false)
        vm.toggle("4"); vm.toggle("5")
        await vm.bulkTable(" 14 ")
        XCTAssertEqual(repo.calls.last, "bulk:table_no=14:[\"4\", \"5\"]")
        XCTAssertEqual(vm.guests.first { $0.id == "5" }?.tableNo, "14")
        vm.toggle("5")
        await vm.bulkSide(.bride)
        XCTAssertEqual(vm.guests.first { $0.id == "5" }?.side, .bride)
        vm.toggle("1")
        await vm.bulkTable("")
        XCTAssertEqual(repo.calls.last, "bulk:table_no=null:[\"1\"]", "empty means no table")
    }

    func testLoadErrorKeepsCachedRows() async {
        let vm = await vm(owner: true)
        repo.listResult = .failure(.network)
        await vm.load()
        XCTAssertEqual(vm.error, .network)
        XCTAssertEqual(vm.guests.count, 5)
    }

    // MARK: real supabase-swift against canned PostgREST answers

    private func supa(_ status: Int, _ body: String) -> SupabaseGuestListRepository {
        StubProtocol.handler = { _ in (status, body) }
        StubProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return SupabaseGuestListRepository(client: makeDevetSupabase(
            SupabaseConfig(url: "https://test.supabase.co", anonKey: "anon-key", publicBaseURL: ""),
            session: URLSession(configuration: configuration), storage: MemoryStorage()
        ))
    }

    private var last: URLRequest { StubProtocol.requests.last! }
    private func query(_ name: String) -> String? { URLComponents(url: last.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value }

    func testListAndLimitRequests() async throws {
        let rows = #"[{"id":"1","code":"K7D2M9QX","salutation":"muellim","name":"Elçin","with_family":true,"invited_count":4,"phone_e164":"+994501234567","side":"groom","table_no":"12","lang":null,"sent_at":"2027-06-01T10:00:00+00:00","opened_at":null,"rsvp_status":"pending","rsvp_count":0,"event_id":"e1","added_by":null}]"#
        let g = try await supa(200, rows).list("e1").get().first!
        XCTAssertEqual(g.status, .pending)
        XCTAssertEqual(g.salutation, .muellim)
        XCTAssertEqual(query("event_id"), "eq.e1")
        XCTAssertTrue(query("order")!.hasPrefix("name.asc"))
        let limit = try await supa(200, "300").limit("e1").get()
        XCTAssertEqual(limit, 300)
        XCTAssertTrue(last.url!.path.hasSuffix("/rpc/event_guest_limit"))
        XCTAssertEqual(String(data: last.httpBody ?? Data(), encoding: .utf8), #"{"p_event_id":"e1"}"#)
    }

    func testBulkAndDeleteRequests() async {
        let r = await supa(200, #"[{"id":"1"},{"id":"2"}]"#).bulkUpdate(["1", "2"], column: "table_no", value: "14")
        XCTAssertNil(r.failure)
        XCTAssertEqual(last.httpMethod, "PATCH")
        XCTAssertEqual(query("id"), "in.(1,2)")
        XCTAssertEqual(String(data: last.httpBody ?? Data(), encoding: .utf8), #"{"table_no":"14"}"#)
        let d = await supa(200, "[]").delete(["1"])
        XCTAssertEqual(d.failure, .forbidden, "co-host: RLS hides the rows")
        XCTAssertEqual(last.httpMethod, "DELETE")
    }
}
