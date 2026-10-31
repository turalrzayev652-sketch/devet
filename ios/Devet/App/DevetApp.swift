import SwiftUI

@main
struct DevetApp: App {
    @StateObject private var dependencies: AppDependencies
    @StateObject private var app: AppModel

    init() {
        let deps = AppDependencies.live()
        _dependencies = StateObject(wrappedValue: deps)
        _app = StateObject(wrappedValue: AppModel(auth: deps.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
                .environmentObject(app)
        }
    }
}
