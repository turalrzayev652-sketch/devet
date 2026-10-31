import XCTest
@testable import Devet

/// The generated string catalog (tools/i18n/generate.mjs) has all four languages and matches spec/i18n/app.json.
final class StringCatalogTests: XCTestCase {
    private let langs = ["az", "ru", "en", "tr"]

    private func catalog() throws -> [String: Any] {
        try RepoFiles.json("ios/Devet/Resources/Localizable.xcstrings")
    }

    func testCatalogIsInSyncWithAppJson() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog["sourceLanguage"] as? String, "az")
        let keys = Set((catalog["strings"] as? [String: Any] ?? [:]).keys)
        let expected = Set(try RepoFiles.json("spec/i18n/app.json").keys.map {
            $0.replacingOccurrences(of: #"\.(one|few|many|other)$"#, with: "", options: .regularExpression)
        })
        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(keys, expected, "run: node tools/i18n/generate.mjs")
    }

    func testEveryKeyHasAllFourLanguages() throws {
        let strings = try XCTUnwrap(try catalog()["strings"] as? [String: [String: Any]])
        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            XCTAssertEqual(Set(localizations.keys), Set(langs), key)
        }
    }

    func testAppBundleShipsTheFourLanguages() throws {
        let bundle = Bundle(for: AppDependencies.self)
        XCTAssertEqual(bundle.developmentLocalization, "az")
        XCTAssertTrue(Set(langs).isSubset(of: Set(bundle.localizations)), "localizations: \(bundle.localizations)")

        let welcome = try XCTUnwrap(try RepoFiles.json("spec/i18n/app.json")["app.welcome"] as? [String: String])
        for lang in langs {
            let path = try XCTUnwrap(bundle.path(forResource: lang, ofType: "lproj"), "no \(lang).lproj")
            let localized = Bundle(path: path)?.localizedString(forKey: "app.welcome", value: nil, table: nil)
            XCTAssertEqual(localized, welcome[lang], lang)
        }
    }

    func testBrandNameIsAConfigValue() {
        XCTAssertEqual(Bundle(for: AppDependencies.self).object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Devet")
    }

    func testMissingSecretsLeaveTheAppUnconfigured() {
        let empty = SupabaseConfig(url: "", anonKey: "", publicBaseURL: "")
        XCTAssertFalse(empty.isConfigured)
        XCTAssertNil(makeDevetSupabase(empty))
        XCTAssertTrue(SupabaseConfig(url: "https://x.supabase.co", anonKey: "k", publicBaseURL: "").isConfigured)
    }
}
