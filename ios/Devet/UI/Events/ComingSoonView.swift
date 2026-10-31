import SwiftUI

/// Stand-in for screens of later modules (guests [6] — T45/T46, templates [4] — T44, join by code [11b] — T4A).
struct ComingSoonView: View {
    let title: Text?

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            if let title { title.devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary).multilineTextAlignment(.center) }
            Text("common.coming_soon").devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
        }
        .padding(Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("comingSoon")
    }
}
