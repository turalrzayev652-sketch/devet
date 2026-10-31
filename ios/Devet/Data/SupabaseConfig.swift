import Foundation
import Supabase

/// Backend settings from the build (`Config/Secrets.xcconfig` → Info.plist). Only the anon key ever reaches the app
/// (CLAUDE.md security rules); access is limited by RLS (spec/api.md §0.1).
struct SupabaseConfig: Equatable {
    let url: String
    let anonKey: String
    let publicBaseURL: String

    var isConfigured: Bool { (url.hasPrefix("https://") || url.hasPrefix("http://")) && !anonKey.isEmpty }

    static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfig {
        func value(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        }
        return SupabaseConfig(url: value("SupabaseURL"), anonKey: value("SupabaseAnonKey"), publicBaseURL: value("PublicBaseURL"))
    }
}

/// Returns nil when the build has no Supabase settings: the app still starts, network features stay disabled.
func makeDevetSupabase(_ config: SupabaseConfig) -> SupabaseClient? {
    guard config.isConfigured, let url = URL(string: config.url) else { return nil }
    return SupabaseClient(supabaseURL: url, supabaseKey: config.anonKey)
}
