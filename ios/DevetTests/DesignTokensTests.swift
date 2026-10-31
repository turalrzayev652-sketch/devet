import CoreText
import SwiftUI
import UIKit
import XCTest
@testable import Devet

/// Keeps the SwiftUI theme equal to spec/design.md (the source of truth), like Android's DesignTokensTest.
final class DesignTokensTests: XCTestCase {
    private var designMd: String!

    override func setUpWithError() throws {
        designMd = try RepoFiles.text("spec/design.md")
    }

    private func color(_ token: String, _ style: UIUserInterfaceStyle) throws -> UIColor {
        let asset = try XCTUnwrap(Color.DS.tokens[token], "no asset for \(token)")
        let color = try XCTUnwrap(UIColor(named: asset, in: Bundle(for: AppDependencies.self), compatibleWith: nil), "missing colour set \(asset)")
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private func hex(_ c: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    private func alpha(_ c: UIColor) -> CGFloat {
        var a: CGFloat = 0
        c.getRed(nil, green: nil, blue: nil, alpha: &a)
        return a
    }

    func testColorTableMatches() throws {
        // | `color.bg.canvas` | `#FAF7F2` | `#151217` | ... |
        let rows = designMd.matches(#"\| `(color\.[\w.]+)` \| `(#[0-9A-Fa-f]{6})` \| `(#[0-9A-Fa-f]{6})` \|"#)
        XCTAssertGreaterThanOrEqual(rows.count, 20, "design.md colour rows not found")
        for row in rows {
            XCTAssertEqual(hex(try color(row[1], .light)), row[2].uppercased(), "light \(row[1])")
            XCTAssertEqual(hex(try color(row[1], .dark)), row[3].uppercased(), "dark \(row[1])")
        }
    }

    func testOverlayMatches() throws {
        // | `color.bg.overlay` | `rgba(31,27,36,.40)` | `rgba(0,0,0,.60)` | ...
        let row = try XCTUnwrap(designMd.matches(#"\| `color\.bg\.overlay` \| `rgba\((\d+),(\d+),(\d+),([.\d]+)\)` \| `rgba\((\d+),(\d+),(\d+),([.\d]+)\)` \|"#).first)
        for (style, i) in [(UIUserInterfaceStyle.light, 1), (.dark, 5)] {
            let c = try color("color.bg.overlay", style)
            let expected = String(format: "#%02X%02X%02X", Int(row[i])!, Int(row[i + 1])!, Int(row[i + 2])!)
            XCTAssertEqual(hex(c), expected)
            XCTAssertEqual(alpha(c), CGFloat(Double(row[i + 3])!), accuracy: 0.005)
        }
    }

    func testStatusTableMatches() throws {
        // | `coming` | Gəlir {n} / … | `#4E7D5B` / `#8CC59A` | `#3F6B4B` / `#8CC59A` | `#E7F0E9` / `#22342A` |
        let pair = "`(#[0-9A-Fa-f]{6})` / `(#[0-9A-Fa-f]{6})`"
        let rows = designMd.matches(#"\| `(coming|declined|viewed|pending|unsent)` \|[^|]*\| "# + pair + " \\| " + pair + " \\| " + pair + " \\|")
        XCTAssertEqual(rows.count, 5, "five status rows")
        for row in rows {
            for (part, i) in [("fg", 2), ("text", 4), ("bg", 6)] {
                let token = "color.status.\(row[1]).\(part)"
                XCTAssertEqual(hex(try color(token, .light)), row[i].uppercased(), "light \(token)")
                XCTAssertEqual(hex(try color(token, .dark)), row[i + 1].uppercased(), "dark \(token)")
            }
        }
    }

    func testEveryColorTokenHasAnAsset() throws {
        XCTAssertEqual(Color.DS.tokens.count, 41)
        for token in Color.DS.tokens.keys {
            _ = try color(token, .light)
        }
    }

    func testTypeScaleMatches() throws {
        // | `type.serif.display` | serif | 34 / 40 | 500 | ...
        let rows = designMd.matches(#"\| `(type\.[\w.]+)` \| (serif|sans) \| (\d+) / (\d+) \| (\d+)"#)
        XCTAssertEqual(rows.count, 10, "ten type tokens")
        for row in rows {
            let token = try XCTUnwrap(DevetType.tokens[row[1]], "missing type token \(row[1])")
            XCTAssertEqual(token.family, row[2] == "serif" ? .serif : .sans, "\(row[1]) family")
            XCTAssertEqual(token.size, CGFloat(Int(row[3])!), "\(row[1]) size")
            XCTAssertEqual(token.lineHeight, CGFloat(Int(row[4])!), "\(row[1]) line height")
            XCTAssertEqual(token.weight, Int(row[5])!, "\(row[1]) weight")
        }
    }

    func testBundledFontsLoadWithTheTokenWeight() throws {
        for (name, token) in DevetType.tokens {
            let font = token.uiFont()
            let family = token.family == .serif ? "Noto Serif Display" : "Inter"
            XCTAssertEqual(font.familyName, family, "\(name) fell back to \(font.familyName) — check UIAppFonts")
            XCTAssertEqual(font.pointSize, token.size, accuracy: 0.01, name)
            // CoreText omits an axis from the variation when it is at its default (Inter: 400).
            let axes = CTFontCopyVariationAxes(font as CTFont) as? [[String: Any]] ?? []
            let axis = try XCTUnwrap(axes.first { ($0[kCTFontVariationAxisIdentifierKey as String] as? Int) == TypeToken.weightAxis }, "\(name) has no wght axis")
            let variation = CTFontCopyVariation(font as CTFont) as NSDictionary?
            let weight = (variation?[NSNumber(value: TypeToken.weightAxis)] as? NSNumber)?.intValue
                ?? (axis[kCTFontVariationAxisDefaultValueKey as String] as? NSNumber)?.intValue
            XCTAssertEqual(weight, token.weight, "\(name) wght axis")
        }
    }

    func testFontsScaleWithDynamicType() {
        let body = DevetType.body
        XCTAssertGreaterThan(body.uiFont(for: .accessibilityExtraLarge).pointSize, body.uiFont().pointSize)
        XCTAssertGreaterThan(body.scaledLineHeight(for: .accessibilityExtraLarge), body.lineHeight)
    }

    func testSpacingRadiusAndSizesMatch() {
        // | `space.0_5` | 4 | | `radius.sm` | 8 (kiçik nişan, thumbnail) |
        let values = Dictionary(designMd.matches(#"`((?:space|radius|size|layout)\.\w+)` \| (\d+)"#).map { ($0[1], CGFloat(Int($0[2])!)) }, uniquingKeysWith: { a, _ in a })
        let expected: [String: CGFloat] = [
            "space.0_5": Spacing.s0_5, "space.1": Spacing.s1, "space.1_5": Spacing.s1_5, "space.2": Spacing.s2,
            "space.3": Spacing.s3, "space.4": Spacing.s4, "space.5": Spacing.s5, "space.6": Spacing.s6, "space.8": Spacing.s8,
            "layout.gutter": Spacing.gutter,
            "radius.sm": Radius.sm, "radius.control": Radius.control, "radius.card": Radius.card, "radius.sheet": Radius.sheet,
            "size.touchMin": Sizes.touchMin, "size.controlHeight": Sizes.controlHeight, "size.chipHeight": Sizes.chipHeight, "size.icon": Sizes.icon,
        ]
        XCTAssertEqual(Set(values.keys), Set(expected.keys), "design.md §4 tokens")
        for (token, value) in expected {
            XCTAssertEqual(values[token], value, token)
        }
    }
}
