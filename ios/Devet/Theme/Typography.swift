import SwiftUI
import UIKit

/// Bundled variable fonts (OFL, `licenses/`), registered through `UIAppFonts` in Info.plist.
/// Both contain all Azerbaijani letters and Cyrillic (checked; spec/design.md §1).
enum DevetFontFamily {
    case serif, sans

    /// PostScript name of the default instance; the weight is set on the `wght` axis.
    var postScriptName: String {
        switch self {
        case .serif: "NotoSerifDisplay-Regular"
        case .sans: "Inter-Regular"
        }
    }
}

/// One `type.*` token from spec/design.md §3. Sizes are points at the default Dynamic Type size.
struct TypeToken {
    let family: DevetFontFamily
    let size: CGFloat
    let lineHeight: CGFloat
    let weight: Int
    /// Letter spacing in em.
    var tracking: CGFloat = 0
    /// Dynamic Type curve the token scales with.
    let textStyle: UIFont.TextStyle

    static let weightAxis = 0x7767_6874 // 'wght'

    /// The font at the given content size; the weight goes through the variable `wght` axis.
    func uiFont(for category: UIContentSizeCategory = .large) -> UIFont {
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(fontAttributes: [.name: family.postScriptName, variation: [Self.weightAxis: weight]])
        let base = UIFont(descriptor: descriptor, size: size)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base, compatibleWith: traits(category))
    }

    func scaledLineHeight(for category: UIContentSizeCategory = .large) -> CGFloat {
        UIFontMetrics(forTextStyle: textStyle).scaledValue(for: lineHeight, compatibleWith: traits(category))
    }

    private func traits(_ category: UIContentSizeCategory) -> UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: category)
    }
}

/// Type tokens (`type.serif.display` → `DevetType.serifDisplay`). Use with `.devetFont(_:)`.
enum DevetType {
    static let serifDisplay = TypeToken(family: .serif, size: 34, lineHeight: 40, weight: 500, tracking: -0.01, textStyle: .largeTitle)
    static let serifTitle = TypeToken(family: .serif, size: 28, lineHeight: 34, weight: 500, textStyle: .title1)
    static let serifHeadline = TypeToken(family: .serif, size: 22, lineHeight: 28, weight: 600, textStyle: .title2)
    static let title1 = TypeToken(family: .sans, size: 28, lineHeight: 34, weight: 600, textStyle: .title1)
    static let title2 = TypeToken(family: .sans, size: 22, lineHeight: 28, weight: 600, textStyle: .title2)
    static let headline = TypeToken(family: .sans, size: 17, lineHeight: 24, weight: 600, textStyle: .headline)
    static let body = TypeToken(family: .sans, size: 17, lineHeight: 24, weight: 400, textStyle: .body)
    static let callout = TypeToken(family: .sans, size: 15, lineHeight: 20, weight: 400, textStyle: .callout)
    static let footnote = TypeToken(family: .sans, size: 13, lineHeight: 18, weight: 400, textStyle: .footnote)
    static let caption = TypeToken(family: .sans, size: 11, lineHeight: 14, weight: 500, tracking: 0.02, textStyle: .caption2)

    /// design.md token name → token, for the comparison test.
    static let tokens: [String: TypeToken] = [
        "type.serif.display": serifDisplay, "type.serif.title": serifTitle, "type.serif.headline": serifHeadline,
        "type.sans.title1": title1, "type.sans.title2": title2, "type.sans.headline": headline,
        "type.sans.body": body, "type.sans.callout": callout, "type.sans.footnote": footnote, "type.sans.caption": caption,
    ]
}

private struct DevetFontModifier: ViewModifier {
    let token: TypeToken
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let category = UIContentSizeCategory(dynamicTypeSize)
        let font = token.uiFont(for: category)
        content
            .font(Font(font))
            .tracking(token.tracking * font.pointSize)
            .lineSpacing(max(0, token.scaledLineHeight(for: category) - font.lineHeight))
    }
}

extension View {
    /// Applies a type token: bundled font, weight, Dynamic Type scaling, line height and tracking.
    func devetFont(_ token: TypeToken) -> some View { modifier(DevetFontModifier(token: token)) }
}

private extension UIContentSizeCategory {
    // UIContentSizeCategory(DynamicTypeSize) exists only from iOS 17.
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}
