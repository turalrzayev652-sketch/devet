import SwiftUI

@main
struct DevetApp: App {
    @StateObject private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
        }
    }
}
