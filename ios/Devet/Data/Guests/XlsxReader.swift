import Foundation
import ZIPFoundation

/// Minimal `.xlsx` reader: the first worksheet as rows of cells (text, number or empty). The zip is opened with
/// ZIPFoundation (owner's decision 2026-10-31); the XML parts are read with XMLParser. Same output as Android `XlsxReader`.
enum XlsxReader {
    struct NotXlsx: Error {}

    /// A guest list never needs more than a few megabytes per part (zip-bomb guard).
    static let partLimit = 20 * 1024 * 1024

    static func read(_ data: Data) throws -> [[ExcelRules.Cell]] {
        let archive: Archive
        do { archive = try Archive(data: data, accessMode: .read) } catch { throw NotXlsx() }
        func part(_ path: String) throws -> Data? {
            guard let entry = archive[path] else { return nil }
            if entry.uncompressedSize > UInt64(partLimit) { throw NotXlsx() }
            var out = Data()
            _ = try archive.extract(entry, skipCRC32: false) { chunk in
                out.append(chunk)
                if out.count > partLimit { throw NotXlsx() }
            }
            return out
        }
        guard let workbook = try part("xl/workbook.xml") else { throw NotXlsx() }
        let shared = try part("xl/sharedStrings.xml").map(sharedStrings) ?? []
        let sheetPath = try firstSheetPath(workbook, rels: part("xl/_rels/workbook.xml.rels"))
        guard let sheet = try sheetPath.flatMap(part) ?? part("xl/worksheets/sheet1.xml") else { throw NotXlsx() }
        return rows(sheet, shared: shared)
    }

    // MARK: - Parts

    private final class Handler: NSObject, XMLParserDelegate {
        var start: (String, [String: String]) -> Void = { _, _ in }
        var end: (String) -> Void = { _ in }
        var text: (String) -> Void = { _ in }
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            start(name, attributes)
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { end(name) }
        func parser(_ parser: XMLParser, foundCharacters string: String) { text(string) }
    }

    private static func parse(_ data: Data, _ handler: Handler) {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = handler
        parser.parse()
    }

    private static func firstSheetPath(_ workbook: Data, rels: Data?) -> String? {
        var rid: String?
        let h = Handler()
        h.start = { name, a in if name == "sheet", rid == nil { rid = a["r:id"] ?? a["id"] ?? a.first { $0.key.hasSuffix(":id") }?.value } }
        parse(workbook, h)
        guard let rid, let rels else { return nil }
        var target: String?
        let r = Handler()
        r.start = { name, a in if name == "Relationship", a["Id"] == rid { target = a["Target"] } }
        parse(rels, r)
        guard let target else { return nil }
        return target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + (target.hasPrefix("./") ? String(target.dropFirst(2)) : target)
    }

    private static func sharedStrings(_ data: Data) -> [String] {
        var result: [String] = []
        var current = ""
        var inSi = false, inT = false, inPhonetic = false
        let h = Handler()
        h.start = { name, _ in
            switch name {
            case "si": inSi = true; current = ""
            case "rPh": inPhonetic = true
            case "t": inT = inSi && !inPhonetic
            default: break
            }
        }
        h.end = { name in
            switch name {
            case "si": result.append(current); inSi = false
            case "rPh": inPhonetic = false
            case "t": inT = false
            default: break
            }
        }
        h.text = { if inT { current += $0 } }
        parse(data, h)
        return result
    }

    private static func rows(_ data: Data, shared: [String]) -> [[ExcelRules.Cell]] {
        var rows: [Int: [Int: ExcelRules.Cell]] = [:]
        var row = 0, col = 0, type = "n", value = "", inValue = false
        let h = Handler()
        h.start = { name, a in
            switch name {
            case "row": row = a["r"].flatMap(Int.init) ?? row + 1
            case "c":
                col = a["r"].map(columnIndex) ?? col + 1
                type = a["t"] ?? "n"
                value = ""
            case "v", "t": inValue = true
            default: break
            }
        }
        h.end = { name in
            switch name {
            case "v", "t": inValue = false
            case "c":
                let cell: ExcelRules.Cell
                if value.isEmpty { cell = .empty }
                else if type == "s" { cell = .text(Int(value.trimmed).flatMap { shared.indices.contains($0) ? shared[$0] : nil } ?? "") }
                else if type == "inlineStr" || type == "str" { cell = .text(value) }
                else if type == "b" { cell = .text(value == "1" ? "true" : "false") }
                else if type == "e" { cell = .empty }
                else { cell = Double(value).map(ExcelRules.Cell.number) ?? .text(value) }
                rows[row, default: [:]][col] = cell
            default: break
            }
        }
        h.text = { if inValue { value += $0 } }
        parse(data, h)
        // Rows keep their position (an empty row in the middle stays empty, then is skipped by the rules).
        guard let last = rows.keys.max() else { return [] }
        return (1...last).map { r in
            let cells = rows[r] ?? [:]
            let width = (cells.keys.max() ?? -1) + 1
            return (0..<width).map { cells[$0] ?? .empty }
        }
    }

    /// "C12" → 2 (0-based).
    private static func columnIndex(_ ref: String) -> Int {
        ref.prefix { $0.isLetter }.uppercased().unicodeScalars.reduce(0) { $0 * 26 + Int($1.value) - 64 } - 1
    }
}
