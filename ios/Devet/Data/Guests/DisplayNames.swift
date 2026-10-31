import Foundation

/// Guest's name as the invitation shows it, in the guest's language (api.md §0.4, PRODUCT.md §8): `salutation.*` +
/// `salutation.family`, and the greeting `greeting.*`. Forms come from spec/i18n/invite.json (copied into the app at
/// build time) — the same forms the server and the guest page use. Same as Android `DisplayNames`.
struct DisplayNames {
    let forms: [String: [String: String]]

    func displayName(_ name: String, _ salutation: Salutation, withFamily: Bool, lang: String) -> String {
        let base = form("salutation.\(salutation.rawValue)", lang).replacingOccurrences(of: "{name}", with: name.trimmed)
        return withFamily ? form("salutation.family", lang).replacingOccurrences(of: "{display}", with: base) : base
    }

    /// "Hörmətli Elçin müəllim və ailəsi!" — the preview under the guest form (screens.md §6.1).
    func greeting(_ name: String, _ salutation: Salutation, withFamily: Bool, lang: String) -> String {
        let key = withFamily ? "greeting.family" : "greeting.\(salutation.rawValue)"
        return form(key, lang).replacingOccurrences(of: "{display_name}", with: displayName(name, salutation, withFamily: withFamily, lang: lang))
    }

    private func form(_ key: String, _ lang: String) -> String { forms[key].flatMap { $0[lang] ?? $0["az"] } ?? "{name}" }

    static func from(invite: Data) throws -> DisplayNames {
        let json = try JSONSerialization.jsonObject(with: invite) as? [String: [String: String]] ?? [:]
        return DisplayNames(forms: json.filter { $0.key.hasPrefix("salutation.") || $0.key.hasPrefix("greeting.") })
    }
}

/// Rules loaded once from the bundled spec files (copied from /spec by the "Copy shared spec files" build phase).
struct GuestSpec {
    let excel: ExcelRules
    let displayNames: DisplayNames
    var phones: Phones { excel.phones }

    static func load(bundle: Bundle = .main) throws -> GuestSpec {
        func data(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "spec") else { throw CocoaError(.fileNoSuchFile) }
            return try Data(contentsOf: url)
        }
        return GuestSpec(excel: try ExcelRules.from(excel: data("excel"), phones: data("phones")), displayNames: try DisplayNames.from(invite: data("invite")))
    }
}
