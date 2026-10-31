import CoreGraphics

/// Spacing tokens (spec/design.md §4, 8-pt grid): `space.2` → `Spacing.s2`.
enum Spacing {
    static let s0_5: CGFloat = 4
    static let s1: CGFloat = 8
    static let s1_5: CGFloat = 12
    static let s2: CGFloat = 16
    static let s3: CGFloat = 24
    static let s4: CGFloat = 32
    static let s5: CGFloat = 40
    static let s6: CGFloat = 48
    static let s8: CGFloat = 64
    static let gutter: CGFloat = 24
}

/// Radius tokens: `radius.card` → `Radius.card`. `radius.pill` is `Capsule()`.
enum Radius {
    static let sm: CGFloat = 8
    static let control: CGFloat = 14
    static let card: CGFloat = 20
    static let sheet: CGFloat = 28
}

/// Size tokens: touch target, control height, icon.
enum Sizes {
    static let touchMin: CGFloat = 44
    static let controlHeight: CGFloat = 52
    static let chipHeight: CGFloat = 36
    static let icon: CGFloat = 24
}

/// Motion tokens (seconds). With Reduce Motion, use `Motion.duration(_:reduceMotion:)` to get 0.
enum Motion {
    static let fast = 0.20
    static let base = 0.25
    static let slow = 0.30

    static func duration(_ value: Double, reduceMotion: Bool) -> Double { reduceMotion ? 0 : value }
}
