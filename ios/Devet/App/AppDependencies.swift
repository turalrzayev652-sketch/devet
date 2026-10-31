import Foundation
import Supabase

/// App-wide services, passed down as an environment object (the iOS counterpart of the Android Koin module).
@MainActor
final class AppDependencies: ObservableObject {
    let config: SupabaseConfig
    /// nil until Secrets.xcconfig is filled in; screens that need the network must handle this.
    let supabase: SupabaseClient?

    init(config: SupabaseConfig, supabase: SupabaseClient?) {
        self.config = config
        self.supabase = supabase
    }

    static func live() -> AppDependencies {
        let config = SupabaseConfig.fromBundle()
        return AppDependencies(config: config, supabase: makeDevetSupabase(config))
    }

    static let preview = AppDependencies(config: SupabaseConfig(url: "", anonKey: "", publicBaseURL: ""), supabase: nil)
}
