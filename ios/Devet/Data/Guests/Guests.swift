import Foundation

/// `salutation` enum (PRODUCT.md §5).
enum Salutation: String, CaseIterable, Identifiable {
    case muellim, xanim, bey, none
    var id: String { rawValue }
    var labelKey: String { "guest.salutation.\(rawValue)" }
}

/// `side` enum.
enum Side: String, CaseIterable, Identifiable {
    case groom, bride, none
    var id: String { rawValue }
    var labelKey: String { "guest.side.\(rawValue)" }
}

/// A guest to insert (api.md §2 [7]); `code` and `added_by` are set by the server. Same as Android `NewGuest`.
struct NewGuest: Equatable {
    var name: String
    var salutation: Salutation = .none
    var withFamily = false
    var invitedCount = 1
    var phoneE164: String?
    var side: Side = .none
    var tableNo: String?
    /// nil = the event's default language.
    var lang: String?
}

/// Field limits shared with the Excel rules (api.md §1 Guest, test-vectors).
enum GuestRules {
    static let maxName = 80
    static let maxCount = 50
    static let maxTable = 12

    static func nameOK(_ v: String) -> Bool { (1...maxName).contains(v.trimmed.count) }
    static func countOK(_ v: Int) -> Bool { (1...maxCount).contains(v) }
    static func tableOK(_ v: String) -> Bool { v.trimmed.count <= maxTable }
}

/// Phone numbers → E.164 (spec/test-vectors/README.md#phones, cases: phones.json). Same algorithm as Android `Phones`.
struct Phones {
    enum Result: Equatable {
        case ok(String)
        /// `empty`, `invalid` or `not_mobile`.
        case error(String)
    }

    let mobilePrefixes: Set<String>

    func normalize(_ input: String?) -> Result {
        var s = (input ?? "").precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"[\s\u00A0\-.()]"#, with: "", options: .regularExpression)
        if s.isEmpty { return .error("empty") }
        if !Self.matches(#"^\+?\d+$"#, s) { return .error("invalid") }
        if s.hasPrefix("00") { s = "+" + s.dropFirst(2) }

        let e164: String
        if s.hasPrefix("+") {
            guard Self.matches(#"^\+[1-9]\d{7,14}$"#, s) else { return .error("invalid") }
            e164 = s
        } else if Self.matches(#"^994\d{9}$"#, s) {
            e164 = "+" + s
        } else if Self.matches(#"^0\d{9}$"#, s) {
            e164 = "+994" + s.dropFirst()
        } else if Self.matches(#"^[1-9]\d{8}$"#, s) {
            e164 = "+994" + s
        } else {
            return .error("invalid")
        }
        if e164.hasPrefix("+994") {
            let national = String(e164.dropFirst(4))
            if national.count != 9 { return .error("invalid") }
            if !mobilePrefixes.contains(String(national.prefix(2))) { return .error("not_mobile") }
        }
        return .ok(e164)
    }

    /// Whole-string match with ASCII digits only (`\d` in ICU also matches other scripts' digits).
    private static func matches(_ pattern: String, _ s: String) -> Bool {
        let ascii = pattern.replacingOccurrences(of: #"\d"#, with: "[0-9]")
        return s.range(of: ascii, options: .regularExpression) != nil
    }
}
