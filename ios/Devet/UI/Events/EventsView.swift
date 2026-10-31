import SwiftUI

/// Screen [2] shell: title and the profile button to Settings. Event list comes in T43.
struct EventsView: View {
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("events.title").devetFont(DevetType.serifDisplay).foregroundStyle(Color.DS.textPrimary)
                    .accessibilityIdentifier("eventsTitle")
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: DevetIcon.user).font(.title3.weight(.light)).foregroundStyle(Color.DS.textPrimary)
                        .frame(width: Sizes.touchMin, height: Sizes.touchMin)
                }
                .accessibilityLabel(Text("settings.title"))
                .accessibilityIdentifier("settings")
            }
            .padding(.top, Spacing.s2)
            Spacer()
            Text("common.coming_soon").devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(.horizontal, Spacing.gutter)
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
