import Foundation

/// `.xlsx` import rules (spec/test-vectors/README.md#excel, cases: excel.json). Aliases and allowed values come
/// from excel.json itself. Same algorithm as Android `ExcelRules`.
struct ExcelRules {
    /// A cell: text, number or empty.
    enum Cell: Equatable {
        case text(String)
        case number(Double)
        case empty
    }

    enum RowResult: Equatable {
        case skipped
        case ok(NewGuest)
        case errors([String])
    }

    struct Warning: Equatable { let row: Int; let firstRow: Int }

    /// Fields in excel.json order: name, phone, salutation, invited_count, with_family, side, table_no.
    let fields: [String]
    let aliases: [String: String]
    let values: [String: [String: String]]
    let phones: Phones

    /// Header row → field → column index; nil when no column maps to `name` (`name_column_missing`).
    func mapHeaders(_ headers: [String]) -> [String: Int]? {
        let m = mapHeadersPartial(headers)
        return m["name"] == nil ? nil : m
    }

    /// Same mapping without requiring `name` — the column screen starts from it when the name column is unknown.
    func mapHeadersPartial(_ headers: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (i, h) in headers.enumerated() {
            if let field = aliases[Self.normalizeHeader(h)], result[field] == nil { result[field] = i }
        }
        return result
    }

    func parseRow(_ row: [String: Cell]) -> RowResult {
        if row.values.allSatisfy(Self.isEmpty) { return .skipped }
        var errors: [String] = []
        var g = NewGuest(name: "")
        for field in fields {
            let raw = row[field] ?? .empty
            switch field {
            case "name":
                g.name = Self.asText(raw)
                if g.name.isEmpty { errors.append("name_missing") }
            case "phone":
                guard !Self.isEmpty(raw) else { break }
                let input: String
                if case let .number(n) = raw { input = String(Int64(n)) } else { input = Self.asText(raw) }
                switch phones.normalize(input) {
                case let .ok(e164): g.phoneE164 = e164
                case let .error(code): errors.append(code == "not_mobile" ? "phone_not_mobile" : "phone_invalid")
                }
            case "salutation":
                if let v = Self.isEmpty(raw) ? "none" : lookup("salutation", raw) { g.salutation = Salutation(rawValue: v) ?? .none } else { errors.append("salutation_invalid") }
            case "invited_count":
                if let n = parseCount(raw) { g.invitedCount = n } else { errors.append("invited_count_invalid") }
            case "with_family":
                if let v = Self.isEmpty(raw) ? "false" : lookup("boolean", raw) { g.withFamily = v == "true" } else { errors.append("with_family_invalid") }
            case "side":
                if let v = Self.isEmpty(raw) ? "none" : lookup("side", raw) { g.side = Side(rawValue: v) ?? .none } else { errors.append("side_invalid") }
            case "table_no":
                guard !Self.isEmpty(raw) else { break }
                let t = Self.asText(raw)
                if t.count > GuestRules.maxTable { errors.append("table_no_invalid") } else { g.tableNo = t }
            default:
                break
            }
        }
        return errors.isEmpty ? .ok(g) : .errors(errors)
    }

    /// Same normalised phone in a later row → `duplicate_phone` warning (1-based data rows).
    func duplicateWarnings(_ results: [RowResult]) -> [Warning] {
        var seen: [String: Int] = [:]
        var warnings: [Warning] = []
        for (i, r) in results.enumerated() {
            guard case let .ok(g) = r, let phone = g.phoneE164 else { continue }
            if let first = seen[phone] { warnings.append(Warning(row: i + 1, firstRow: first)) } else { seen[phone] = i + 1 }
        }
        return warnings
    }

    private func lookup(_ table: String, _ raw: Cell) -> String? { values[table]?[Self.normalizeValue(Self.asText(raw))] }

    private func parseCount(_ raw: Cell) -> Int? {
        let n: Double
        switch raw {
        case .empty: return 1
        case let .number(v): n = v
        case let .text(t):
            let s = t.trimmed
            if s.isEmpty { return 1 }
            guard let v = Double(s) else { return nil }
            n = v
        }
        guard n == n.rounded(.down), n.isFinite else { return nil }
        let i = Int(n)
        return GuestRules.countOK(i) ? i : nil
    }

    // MARK: - Normalisation (README "fold")

    static func isEmpty(_ c: Cell) -> Bool {
        switch c {
        case .empty: true
        case let .text(t): t.trimmed.isEmpty
        case .number: false
        }
    }

    /// Numbers become text the way JavaScript prints them: 5.0 → "5", 2.5 → "2.5".
    static func asText(_ c: Cell) -> String {
        switch c {
        case let .text(t): t.trimmed
        case let .number(n): n == n.rounded(.down) && n.isFinite ? String(Int64(n)) : String(n)
        case .empty: ""
        }
    }

    static func fold(_ text: String) -> String {
        let lower = text.precomposedStringWithCompatibilityMapping.lowercased()
            .replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "ə", with: "e")
        let stripped = String(String.UnicodeScalarView(lower.decomposedStringWithCanonicalMapping.unicodeScalars.filter {
            ![.nonspacingMark, .spacingMark, .enclosingMark].contains($0.properties.generalCategory)
        }))
        return stripped.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    static func normalizeHeader(_ text: String) -> String {
        fold(text).replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    static func normalizeValue(_ text: String) -> String { fold(text) }

    // MARK: - Loading

    /// Column order of excel.json (README table); errors are listed in this order. JSONSerialization does not keep
    /// key order, so the order is fixed here and checked against the file by the tests.
    static let fieldOrder = ["name", "phone", "salutation", "invited_count", "with_family", "side", "table_no"]

    /// Builds the rules from excel.json and phones.json data.
    static func from(excel: Data, phones: Data) throws -> ExcelRules {
        let e = try JSONSerialization.jsonObject(with: excel) as? [String: Any] ?? [:]
        let columns = e["columns"] as? [String: [String: Any]] ?? [:]
        let order = fieldOrder.filter { columns[$0] != nil }
        var aliases: [String: String] = [:]
        for field in order {
            for a in columns[field]?["aliases"] as? [String] ?? [] where aliases[normalizeHeader(a)] == nil { aliases[normalizeHeader(a)] = field }
        }
        var values: [String: [String: String]] = [:]
        for (table, map) in e["values"] as? [String: [String: [String]]] ?? [:] {
            var out: [String: String] = [:]
            for (key, list) in map.sorted(by: { $0.key < $1.key }) {
                for alias in list where out[normalizeValue(alias)] == nil { out[normalizeValue(alias)] = key }
            }
            values[table] = out
        }
        return ExcelRules(fields: order, aliases: aliases, values: values, phones: try phonesFrom(phones))
    }

    static func phonesFrom(_ data: Data) throws -> Phones {
        let p = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return Phones(mobilePrefixes: Set(p["az_mobile_prefixes"] as? [String] ?? []))
    }
}
