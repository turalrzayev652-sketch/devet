import SwiftUI

/// Inside an event until the guest list (screen [6], T46) exists: guest count and the three ways to add guests
/// (the empty state of [6], screens.md §6). Same as Android `EventHomeScreen`.
struct EventHomeView: View {
    let eventId: String
    let title: String
    let reloadToken: Int
    let guests: any GuestRepository
    let onAdd: (Int) -> Void
    @State private var count: Int?

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            Spacer()
            Text(verbatim: title).devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary).multilineTextAlignment(.center)
            if let count, count > 0 {
                Text(plural("guests.count", count)).devetFont(DevetType.title2).foregroundStyle(Color.DS.brandPrimary)
                Text("common.coming_soon").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            } else {
                EnvelopeArt().stroke(Color.DS.accentGold, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 160, height: 124).accessibilityHidden(true)
                Text("guests.empty.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
                Text("guests.empty.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            }
            PrimaryButton(title: "guests.add.manual") { onAdd(0) }.padding(.top, Spacing.s2)
            LinkButton(title: "guests.add.contacts") { onAdd(1) }
            LinkButton(title: "guests.add.excel") { onAdd(2) }
            Spacer()
        }
        .padding(Spacing.gutter)
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) { if case let .success(n) = await guests.count(eventId) { count = n } }
    }
}
