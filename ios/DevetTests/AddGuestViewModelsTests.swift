import XCTest
import ZIPFoundation
@testable import Devet

final class FakeGuests: GuestRepository, @unchecked Sendable {
    var existing = [GuestPhone(name: "Elçin", phoneE164: "+994501234567")]
    var result: AddResult?
    var batches: [[NewGuest]] = []
    func phones(_ eventId: String) async -> Result<[GuestPhone], AuthFailure> { .success(existing) }
    func count(_ eventId: String) async -> Result<Int, AuthFailure> { .success(existing.count) }
    func add(_ eventId: String, _ guests: [NewGuest]) async -> AddResult { batches.append(guests); return result ?? .added(guests.count) }
}

/// Same scenarios as Android `AddGuestViewModelsTest`.
@MainActor
final class AddGuestViewModelsTests: XCTestCase {
    private var guests: FakeGuests!
    private var events: FakeEvents!
    private lazy var spec: GuestSpec = {
        func d(_ p: String) -> Data { try! Data(contentsOf: RepoFiles.root.appendingPathComponent(p)) }
        return GuestSpec(excel: try! ExcelRules.from(excel: d("spec/test-vectors/excel.json"), phones: d("spec/test-vectors/phones.json")),
                         displayNames: try! DisplayNames.from(invite: d("spec/i18n/invite.json")))
    }()

    override func setUp() async throws {
        guests = FakeGuests()
        events = FakeEvents()
        events.getResult = .success(EventDraft(defaultLang: "ru"))
    }

    private func ctx() -> GuestContext { GuestContext(eventId: "e1", guests: guests, events: events) }

    func testManualSaveAndNextKeepsSideTableLanguage() async {
        let vm = ManualGuestViewModel(ctx: ctx(), spec: spec)
        await vm.load()
        XCTAssertEqual(vm.eventLang, "ru", "event language for the preview")
        vm.form = GuestForm(salutation: .xanim, name: "Leyla", count: 2, phone: "055 111 22 33", side: .bride, table: "7", lang: "az")
        await vm.save(andNext: true)
        XCTAssertEqual(guests.batches.first?.first, NewGuest(name: "Leyla", salutation: .xanim, withFamily: false, invitedCount: 2, phoneE164: "+994551112233", side: .bride, tableNo: "7", lang: "az"))
        XCTAssertEqual(vm.form.name, "")
        XCTAssertEqual(vm.form.salutation, .none)
        XCTAssertEqual(vm.form.side, .bride)
        XCTAssertEqual(vm.form.table, "7")
        XCTAssertEqual(vm.form.lang, "az")
        XCTAssertEqual(vm.added, "Leyla xanım")
    }

    func testManualPhoneProblemsAndDuplicates() async {
        let vm = ManualGuestViewModel(ctx: ctx(), spec: spec)
        await vm.load()
        vm.form.name = "Tural"; vm.form.phone = "012 345 67 89"
        XCTAssertEqual(vm.phoneProblem, .notMobile)
        XCTAssertFalse(vm.canSave)
        vm.form.phone = "12345"
        XCTAssertEqual(vm.phoneProblem, .invalid)
        vm.form.phone = "+994 50 123 45 67"
        XCTAssertEqual(vm.phoneProblem, .none)
        XCTAssertEqual(vm.duplicateOf, "Elçin", "duplicate is a warning only")
        XCTAssertTrue(vm.canSave)
        vm.form.phone = ""
        XCTAssertTrue(vm.canSave, "phone is optional")
    }

    func testManualEmptyNameShowsError() async {
        let vm = ManualGuestViewModel(ctx: ctx(), spec: spec)
        await vm.save(andNext: true)
        XCTAssertTrue(vm.nameError)
        XCTAssertTrue(guests.batches.isEmpty)
    }

    func testManualLimitKeepsTheForm() async {
        guests.result = .limitExceeded(100)
        let vm = ManualGuestViewModel(ctx: ctx(), spec: spec)
        vm.form.name = "Leyla"
        await vm.save(andNext: true)
        XCTAssertEqual(vm.limit?.limit, 100)
        XCTAssertEqual(vm.form.name, "Leyla")
    }

    func testContactsWithoutMobileAreAddedWithoutPhone() async {
        let vm = ContactsViewModel(ctx: ctx(), spec: spec)
        await vm.load()
        vm.picked(name: "Ana", numbers: ["+994 12 345 67 89"])
        vm.picked(name: "Rəşad", numbers: ["050-123-45-67"])
        XCTAssertTrue(vm.picked[0].noMobile)
        XCTAssertNil(vm.picked[0].phoneE164)
        XCTAssertEqual(vm.picked[1].duplicateOf, "Elçin")
        vm.edit(vm.picked[1].id) { $0.salutation = .bey; $0.count = 3 }
        await vm.addAll()
        XCTAssertEqual(guests.batches.first, [NewGuest(name: "Ana"), NewGuest(name: "Rəşad", salutation: .bey, invitedCount: 3, phoneE164: "+994501234567")])
        XCTAssertTrue(vm.picked.isEmpty)
        XCTAssertEqual(vm.addedCount, 2)
    }

    func testContactWithSeveralMobilesAsksWhichOne() {
        let vm = ContactsViewModel(ctx: ctx(), spec: spec)
        vm.picked(name: "Nərmin", numbers: ["050 111 22 33", "+994 12 444 55 66", "055 777 88 99"])
        XCTAssertEqual(vm.choosing?.numbers, ["050 111 22 33", "055 777 88 99"], "only mobile numbers are offered (§15.7)")
        XCTAssertTrue(vm.picked.isEmpty)
        vm.add(name: "Nərmin", number: "055 777 88 99")
        XCTAssertEqual(vm.picked.first?.phoneE164, "+994557778899")
    }

    /// Minimal .xlsx with inline strings and numbers, for feeding the real reader.
    private func xlsx(_ rows: [[Any?]]) throws -> Data {
        var sheet = #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>"#
        for (r, row) in rows.enumerated() {
            sheet += "<row r=\"\(r + 1)\">"
            for (c, v) in row.enumerated() {
                let ref = "\(Character(UnicodeScalar(65 + c)!))\(r + 1)"
                switch v {
                case let n as Int: sheet += "<c r=\"\(ref)\"><v>\(n)</v></c>"
                case let s as String where !s.isEmpty: sheet += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(s)</t></is></c>"
                default: break
                }
            }
            sheet += "</row>"
        }
        sheet += "</sheetData></worksheet>"
        let archive = try Archive(accessMode: .create)
        for (name, body) in [("xl/workbook.xml", "<workbook/>"), ("xl/worksheets/sheet1.xml", sheet)] {
            let bytes = Data(body.utf8)
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(bytes.count)) { pos, size in bytes.subdata(in: Int(pos)..<Int(pos) + size) }
        }
        return archive.data!
    }

    func testExcelMappingSummaryAndImport() async throws {
        let vm = ExcelImportViewModel(ctx: ctx(), spec: spec)
        await vm.load()
        let file = try xlsx([["Ad", "Telefon", "Qeyd"], ["Leyla", "0551112233", "x"], ["", "0551112244"], ["Kamran", 501234567], [], ["Ana", "0551112233"]])
        await vm.open(fileName: "toy.xlsx") { file }
        guard case let .mapping(m) = vm.step else { return XCTFail("\(vm.step)") }
        XCTAssertEqual(m.columns, [0: "name", 1: "phone"])
        XCTAssertEqual(m.rows.count, 5)
        vm.toSummary()
        guard case let .summary(s) = vm.step else { return XCTFail("\(vm.step)") }
        XCTAssertEqual(s.guests.map(\.name), ["Leyla", "Kamran", "Ana"])
        XCTAssertEqual(s.errors, [ErrorRow(sheetRow: 3, codes: ["name_missing"])], "sheet row 3 (header is row 1)")
        XCTAssertEqual(s.duplicates, 2, "Ana repeats Leyla's number; Kamran's is already in the event")

        guests.result = .limitExceeded(100)
        await vm.importAll()
        XCTAssertEqual(vm.limit?.limit, 100)
        if case .summary = vm.step {} else { XCTFail("summary kept for a retry") }

        guests.result = nil
        vm.limit = nil
        await vm.importAll()
        XCTAssertEqual(vm.addedCount, 3)
        XCTAssertEqual(vm.step, .pick)
        XCTAssertEqual(guests.batches.count, 2)
        XCTAssertEqual(guests.batches.last?.count, 3, "one request per import")
    }

    func testExcelWithoutNameColumnLetsTheUserPickIt() {
        let vm = ExcelImportViewModel(ctx: ctx(), spec: spec)
        guard case let .mapping(m) = vm.mappingFor("x.xlsx", [[.text("Qonaqlar"), .text("Telefon")], [.text("Leyla"), .text("0551112233")]]) else { return XCTFail() }
        XCTAssertFalse(m.hasName)
        XCTAssertEqual(m.columns, [1: "phone"])
        XCTAssertEqual(vm.mappingFor("x.xlsx", [[.text("Ad")]]), .fileError(noRows: true))
        XCTAssertEqual(vm.mappingFor("x.xlsx", nil), .fileError(noRows: false))
    }
}
