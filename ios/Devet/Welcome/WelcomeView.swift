import SwiftUI

/// Placeholder start screen for T41I: proves theme, fonts and the four string sets. Replaced by Sign in (T42).
struct WelcomeView: View {
    private let brandName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""

    var body: some View {
        ZStack {
            Color.DS.bgCanvas.ignoresSafeArea()
            VStack(spacing: Spacing.s1_5) {
                Text(brandName.prefix(1))
                    .devetFont(DevetType.serifTitle)
                    .foregroundStyle(Color.DS.brandPrimary)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.DS.bgSurface))
                    .overlay(Circle().stroke(Color.DS.accentGold, lineWidth: 1))
                    .accessibilityHidden(true)
                Text(brandName)
                    .devetFont(DevetType.serifDisplay)
                    .foregroundStyle(Color.DS.textPrimary)
                Text("app.welcome")
                    .devetFont(DevetType.serifHeadline)
                    .foregroundStyle(Color.DS.textPrimary)
                    .accessibilityIdentifier("welcome")
                Text("app.tagline")
                    .devetFont(DevetType.callout)
                    .foregroundStyle(Color.DS.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: Spacing.s3)
                Button {} label: {
                    Text("auth.login.title")
                        .devetFont(DevetType.headline)
                        .frame(maxWidth: .infinity, minHeight: Sizes.controlHeight)
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("app.language")
                    .devetFont(DevetType.footnote)
                    .foregroundStyle(Color.DS.textSecondary)
            }
            .padding(.horizontal, Spacing.gutter)
        }
    }
}

/// Main action button: brand fill, `radius.control`, pressed colour.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.DS.textOnBrand)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(configuration.isPressed ? Color.DS.brandPressed : Color.DS.brandPrimary)
            )
    }
}

#Preview("Light") {
    WelcomeView().preferredColorScheme(.light)
}

#Preview("Dark") {
    WelcomeView().preferredColorScheme(.dark)
}
