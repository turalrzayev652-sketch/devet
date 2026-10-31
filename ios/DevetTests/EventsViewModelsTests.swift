import XCTest
@testable import Devet

final class FakeEvents: EventRepository, @unchecked Sendable {
    var calls: [String] = []
    var listResult: Result<[EventSummary], AuthFailure> = .success([])
    var getResult: Result<EventDraft, AuthFailure> = .success(EventDraft())
    var createResult: Result<String, AuthFailure> = .success("new-id")
    var updateResult: Result<Void, AuthFailure> = .success(())
    var deleteResult: Result<Void, AuthFailure> = .success(())
    var lastCreated: EventDraft?
    var lastUpdate: (EventDraft, EventDraft)?

    func list() async -> Result<[EventSummary], AuthFailure> { calls.append("list"); return listResult }
    func get(_ id: String) async -> Result<EventDraft, AuthFailure> { calls.append("get:\(id)"); return getResult }
    func create(_ draft: EventDraft) async -> Result<String, AuthFailure> { calls.append("create"); lastCreated = draft; return createResult }
    func update(_ id: String, before: EventDraft, after: EventDraft) async -> Result<Void, AuthFailure> {
        calls.append("update:\(id)"); lastUpdate = (before, after); return updateResult
    }
    func delete(_ id: String) async -> Result<Void, AuthFailure> { calls.append("delete:\(id)"); return deleteResult }
}

final class MemoryArchive: ArchiveStore {
    private var ids = Set<String>()
    func archived() -> Set<String> { ids }
    func setArchived(_ id: String, _ archived: Bool) { if archived { ids.insert(id) } else { ids.remove(id) } }
}

/// Same scenarios as Android `EventsViewModelsTest`.
@MainActor
final class EventsViewModelsTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2027-01-10T10:00:00Z")!
    private var repo: FakeEvents!

    override func setUp() async throws { repo = FakeEvents() }

    private func event(_ id: String, _ days: Double, _ role: MemberRole = .owner) -> EventSummary {
        EventSummary(id: id, type: .wedding, titleNames: "Event \(id)", startsAt: now.addingTimeInterval(days * 86400), venueName: "Hall",
                     thumbnailURL: nil, role: role, guestCount: 10, comingPeople: 4, noAnswer: 3)
    }

    func testListSplitsActiveAndArchive() async {
        repo.listResult = .success([event("old", -30), event("far", 60), event("soon", 5), event("recent", -2)])
        let vm = EventsViewModel(repo: repo, archive: MemoryArchive()) { self.now }
        await vm.load()
        XCTAssertEqual(vm.active.map(\.id), ["soon", "far", "recent"], "upcoming soonest first, then the last 7 days")
        XCTAssertEqual(vm.archived.map(\.id), ["old"])
        XCTAssertFalse(vm.loading)
    }

    func testManualArchiveIsLocalAndReversible() async {
        repo.listResult = .success([event("a", 5), event("old", -30)])
        let vm = EventsViewModel(repo: repo, archive: MemoryArchive()) { self.now }
        await vm.load()
        let a = vm.active[0]
        vm.setArchived(a, true)
        XCTAssertTrue(vm.active.isEmpty)
        XCTAssertTrue(vm.canUnarchive(a))
        XCTAssertFalse(vm.canUnarchive(vm.archived.first { $0.id == "old" }!), "date-based archive cannot be undone")
        vm.setArchived(a, false)
        XCTAssertEqual(vm.active.map(\.id), ["a"])
        XCTAssertFalse(repo.calls.contains { $0.hasPrefix("update") }, "no server call for archiving")
    }

    func testDeleteRemovesTheCard() async {
        repo.listResult = .success([event("a", 5)])
        let vm = EventsViewModel(repo: repo, archive: MemoryArchive()) { self.now }
        await vm.load()
        vm.deleteTarget = vm.active[0]
        await vm.confirmDelete()
        XCTAssertEqual(repo.calls.last, "delete:a")
        XCTAssertTrue(vm.events.isEmpty)
        XCTAssertTrue(vm.deletedMessage)
        XCTAssertNil(vm.deleteTarget)
    }

    func testCohostDeleteRefusedByServerKeepsTheCard() async {
        repo.listResult = .success([event("a", 5, .cohost)])
        repo.deleteResult = .failure(.forbidden)
        let vm = EventsViewModel(repo: repo, archive: MemoryArchive()) { self.now }
        await vm.load()
        vm.deleteTarget = vm.active[0]
        await vm.confirmDelete()
        XCTAssertEqual(vm.events.count, 1)
        XCTAssertEqual(vm.actionError, .forbidden)
    }

    func testLoadErrorKeepsCachedCards() async {
        repo.listResult = .success([event("a", 5)])
        let vm = EventsViewModel(repo: repo, archive: MemoryArchive()) { self.now }
        await vm.load()
        repo.listResult = .failure(.network)
        await vm.load()
        XCTAssertEqual(vm.error, .network)
        XCTAssertEqual(vm.events.count, 1)
    }

    func testWizardWalksSixStepsAndCreates() async {
        let vm = CreateEventViewModel(repo: repo, language: FakeLanguage(effective: "ru")) { self.now }
        XCTAssertEqual(vm.draft.defaultLang, "ru", "default language = app language")
        await vm.next()
        XCTAssertEqual(vm.step, 1, "type missing — stays on step 1")
        vm.draft.type = .henna; await vm.next()
        vm.draft.titleNames = "Aysel"; await vm.next()
        vm.draft.startsAt = now.addingTimeInterval(-3600); await vm.next()
        XCTAssertEqual(vm.step, 3, "past date blocked")
        vm.draft.startsAt = now.addingTimeInterval(86400); await vm.next()
        vm.draft.venueName = "Hall"; vm.draft.mapsURL = "javascript:alert(1)"; await vm.next()
        XCTAssertEqual(vm.step, 4, "invalid link blocked")
        vm.draft.mapsURL = ""; await vm.next()
        await vm.next()
        XCTAssertEqual(vm.step, 6)
        XCTAssertFalse(vm.draft.showTablemates, "tablemates off by default")
        vm.back()
        XCTAssertEqual(vm.step, 5)
        await vm.next(); await vm.next()
        XCTAssertEqual(vm.createdId, "new-id")
        XCTAssertEqual(repo.lastCreated?.type, .henna)
    }

    func testFailedCreateKeepsTheForm() async {
        repo.createResult = .failure(.network)
        let vm = CreateEventViewModel(repo: repo, language: FakeLanguage()) { self.now }
        vm.draft = EventDraft(type: .wedding, titleNames: "A", startsAt: now.addingTimeInterval(86400), venueName: "H")
        for _ in 0..<6 { await vm.next() }
        XCTAssertEqual(vm.error, .network)
        XCTAssertNil(vm.createdId)
        XCTAssertEqual(vm.draft.titleNames, "A")
        XCTAssertEqual(vm.step, 6)
    }

    func testEditOfPastEventAllowsOtherChangesButNotAPastDate() async {
        let past = EventDraft(type: .wedding, titleNames: "A", startsAt: now.addingTimeInterval(-86400), venueName: "Hall")
        repo.getResult = .success(past)
        let vm = EditEventViewModel(repo: repo, eventId: "e1") { self.now }
        await vm.load()
        XCTAssertFalse(vm.canSave, "nothing changed")
        vm.draft.venueName = "New hall"
        XCTAssertTrue(vm.canSave)
        vm.draft.startsAt = now.addingTimeInterval(-7200)
        XCTAssertFalse(vm.canSave, "another past date")
        vm.draft.startsAt = now.addingTimeInterval(7200)
        await vm.save()
        XCTAssertEqual(repo.calls.last, "update:e1")
        XCTAssertEqual(repo.lastUpdate?.0, past)
        XCTAssertTrue(vm.saved)
    }

    func testMapStatusTexts() {
        XCTAssertEqual(mapStatus(""), .none)
        XCTAssertEqual(mapStatus("https://maps.google.com/?q=40.3536,49.8364"), .coordsFound)
        XCTAssertEqual(mapStatus("https://maps.app.goo.gl/AbCdEf123"), .noCoords)
        XCTAssertEqual(mapStatus("ftp://maps.google.com/?q=1,2"), .invalid)
    }
}
