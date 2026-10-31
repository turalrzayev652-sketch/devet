import SwiftUI

/// Screens reachable by push navigation (spec/screens.md §0). Filled in from T42 on.
enum Route: Hashable {}

struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView()
                .navigationDestination(for: Route.self) { _ in EmptyView() }
        }
        .tint(Color.DS.brandPrimary)
    }
}
