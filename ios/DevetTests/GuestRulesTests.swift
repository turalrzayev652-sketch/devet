import XCTest
import ZIPFoundation
@testable import Devet

/// spec/test-vectors phones.json and excel.json case by case — same cases as Android `GuestRulesTest`.
final class GuestRulesTests: XCTestCase {
    private func data(_ path: String) throws -> Data { try Data(contentsOf: RepoFiles.root.appendingPathComponent(path)) }
    private lazy var rules = try! ExcelRules.from(excel: data("spec/test-vectors/excel.json"), phones: data("spec/test-vectors/phones.json"))
    private lazy var excel = try! RepoFiles.json("spec/test-vectors/excel.json")

    func testPhoneVectors() throws {
        let phones = try ExcelRules.phonesFrom(data("spec/test-vectors/phones.json"))
        let cases = try XCTUnwrap(try RepoFiles.json("spec/test-vectors/phones.json")["cases"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(cases.count, 40)
        for c in cases {
            let input = c["input"] as! String
            if let expected = c["expected"] as? String {
                XCTAssertEqual(phones.normalize(input), .ok(expected), input)
            } else {
                XCTAssertEqual(phones.normalize(input), .error(c["error"] as! String), input)
            }
        }
    }

    func testFieldOrderMatchesExcelJson() throws {
        // excel.json key order, read from the text (JSONSerialization does not keep it).
        let text = String(decoding: try data("spec/test-vectors/excel.json"), as: UTF8.self)
        let positions = ExcelRules.fieldOrder.map { text.range(of: "\"\($0)\": {")!.lowerBound }
        XCTAssertEqual(positions, positions.sorted(), "fieldOrder must follow excel.json → columns")
        XCTAssertEqual(Set((excel["columns"] as! [String: Any]).keys), Set(ExcelRules.fieldOrder))
    }

    func testHeaderVectors() {
        for c in excel["header_cases"] as! [[String: Any]] {
            let headers = c["headers"] as! [String]
            XCTAssertEqual(rules.mapHeaders(headers), c["expected"] as? [String: Int], "\(headers)")
        }
    }

    private func cell(_ v: Any?) -> ExcelRules.Cell {
        switch v {
        case nil, is NSNull: .empty
        case let s as String: .text(s)
        case let n as NSNumber: .number(n.doubleValue)
        default: .text("\(v!)")
        }
    }

    private func row(_ o: [String: Any]) -> [String: ExcelRules.Cell] { o.mapValues(cell) }

    func testRowVectors() {
        for c in excel["row_cases"] as! [[String: Any]] {
            let input = c["row"] as! [String: Any]
            let result = rules.parseRow(row(input))
            if c["skipped"] as? Bool == true {
                XCTAssertEqual(result, .skipped, "\(input)")
            } else if let errors = c["errors"] as? [String] {
                XCTAssertEqual(result, .errors(errors), "\(input)")
            } else {
                let e = c["expected"] as! [String: Any]
                guard case let .ok(g) = result else { XCTFail("expected ok for \(input), got \(result)"); continue }
                XCTAssertEqual(g.name, e["name"] as? String)
                XCTAssertEqual(g.phoneE164, e["phone_e164"] as? String)
                XCTAssertEqual(g.salutation.rawValue, e["salutation"] as? String)
                XCTAssertEqual(g.invitedCount, e["invited_count"] as? Int)
                XCTAssertEqual(g.withFamily, e["with_family"] as? Bool)
                XCTAssertEqual(g.side.rawValue, e["side"] as? String)
                XCTAssertEqual(g.tableNo, e["table_no"] as? String)
            }
        }
    }

    func testFileVectors() {
        for c in excel["file_cases"] as! [[String: Any]] {
            let rows = (c["rows"] as! [[String: Any]]).map(row)
            if c["error"] != nil { XCTAssertTrue(rows.isEmpty); continue }
            let expected = (c["expected_warnings"] as! [[String: Any]]).map { ExcelRules.Warning(row: $0["row"] as! Int, firstRow: $0["first_row"] as! Int) }
            XCTAssertEqual(rules.duplicateWarnings(rows.map(rules.parseRow)), expected)
        }
    }

    func testDisplayNamesFromInviteJson() throws {
        let names = try DisplayNames.from(invite: data("spec/i18n/invite.json"))
        // PRODUCT.md §8 table.
        XCTAssertEqual(names.displayName("Elçin", .muellim, withFamily: false, lang: "az"), "Elçin müəllim")
        XCTAssertEqual(names.displayName("Elchin", .muellim, withFamily: false, lang: "en"), "Mr. Elchin")
        XCTAssertEqual(names.displayName("Leyla", .xanim, withFamily: false, lang: "tr"), "Leyla Hanım")
        XCTAssertEqual(names.displayName("Elçin", .muellim, withFamily: true, lang: "ru"), "Elçin муаллим с семьёй")
        XCTAssertEqual(names.greeting("Elçin", .muellim, withFamily: true, lang: "az"), "Hörmətli Elçin müəllim və ailəsi!")
        XCTAssertEqual(names.greeting("Leyla", .xanim, withFamily: false, lang: "ru"), "Уважаемая Leyla ханум!")
    }

    func testSampleXlsxReadsAndImports() throws {
        let rows = try XlsxReader.read(data("android/app/src/main/assets/sample/guests-sample.xlsx"))
        let mapping = try XCTUnwrap(rules.mapHeaders(rows[0].map(ExcelRules.asText)))
        XCTAssertEqual(mapping.count, 7)
        let parsed = rows.dropFirst().map { r in rules.parseRow(mapping.mapValues { $0 < r.count ? r[$0] : .empty }) }
        guard case let .ok(first) = parsed.first else { return XCTFail("\(parsed)") }
        XCTAssertTrue(parsed.allSatisfy { if case .ok = $0 { true } else { false } }, "\(parsed)")
        XCTAssertEqual(first.phoneE164, "+994501234567")
        XCTAssertEqual(first.invitedCount, 4)
        XCTAssertTrue(first.withFamily)
    }

    private func zip(_ parts: [(String, String)]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        for (name, body) in parts {
            let bytes = Data(body.utf8)
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(bytes.count), compressionMethod: .deflate) { pos, size in
                bytes.subdata(in: Int(pos)..<Int(pos) + size)
            }
        }
        return archive.data!
    }

    func testSharedStringsAndGaps() throws {
        let shared = #"<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Ad</t></si><si><t>Telefon</t></si><si><r><t>Elç</t></r><r><t>in</t></r></si></sst>"#
        let sheet = #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row><row r="3"><c r="A3" t="s"><v>2</v></c><c r="C3"><v>501234567</v></c></row></sheetData></worksheet>"#
        let wb = #"<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="S" sheetId="1" r:id="rId7"/></sheets></workbook>"#
        let rels = #"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId7" Type="worksheet" Target="worksheets/data.xml"/></Relationships>"#
        let rows = try XlsxReader.read(zip([("xl/workbook.xml", wb), ("xl/_rels/workbook.xml.rels", rels), ("xl/sharedStrings.xml", shared), ("xl/worksheets/data.xml", sheet)]))
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], [.text("Ad"), .empty, .text("Telefon")])
        XCTAssertTrue(rows[1].isEmpty, "empty middle row")
        XCTAssertEqual(rows[2][0], .text("Elçin"))
        XCTAssertEqual(rows[2][2], .number(501234567))
    }

    /// TASKS.md T45: a 300-row Excel file is read and checked in under 5 seconds.
    func testThreeHundredRowsUnderFiveSeconds() throws {
        var sheet = #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Ad</t></is></c><c r="B1" t="inlineStr"><is><t>Telefon</t></is></c><c r="C1" t="inlineStr"><is><t>Masa</t></is></c></row>"#
        for r in 2...301 {
            sheet += #"<row r="\#(r)"><c r="A\#(r)" t="inlineStr"><is><t>Qonaq \#(r)</t></is></c><c r="B\#(r)"><v>50\#(1_000_000 + r)</v></c><c r="C\#(r)"><v>\#(r % 30)</v></c></row>"#
        }
        sheet += "</sheetData></worksheet>"
        let file = try zip([("xl/workbook.xml", "<workbook/>"), ("xl/worksheets/sheet1.xml", sheet)])
        let start = Date()
        let rows = try XlsxReader.read(file)
        let mapping = try XCTUnwrap(rules.mapHeaders(rows[0].map(ExcelRules.asText)))
        let parsed = rows.dropFirst().map { r in rules.parseRow(mapping.mapValues { $0 < r.count ? r[$0] : .empty }) }
        _ = rules.duplicateWarnings(Array(parsed))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(parsed.filter { if case .ok = $0 { true } else { false } }.count, 300)
        XCTAssertLessThan(elapsed, 5, "took \(elapsed) s")
    }

    func testNotAnXlsx() {
        XCTAssertThrowsError(try XlsxReader.read(Data("hello".utf8)))
    }

    func testFoldMatchesReadme() {
        XCTAssertEqual(ExcelRules.normalizeHeader("  AD SOYAD "), "ad soyad")
        XCTAssertEqual(ExcelRules.normalizeHeader("Adı"), "adi")
        XCTAssertEqual(ExcelRules.normalizeHeader("Nömrə"), "nomre")
        XCTAssertNil(rules.mapHeaders(["Telefon"]))
    }
}
