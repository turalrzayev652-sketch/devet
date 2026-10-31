import Foundation
import Supabase

/// App-wide services, passed down as an environment object (the iOS counterpart of the Android Koin module).
@MainActor
final class AppDependencies: ObservableObject {
    let config: SupabaseConfig
    let auth: any AuthRepository
    let account: any AccountRepository
    let connectivity: Connectivity
    let language: any AppLanguage

    init(config: SupabaseConfig, auth: any AuthRepository, account: any AccountRepository, connectivity: Connectivity, language: any AppLanguage) {
        self.config = config
        self.auth = auth
        self.account = account
        self.connectivity = connectivity
        self.language = language
    }

    /// Without backend settings the client is nil and repositories report `AuthFailure.notConfigured`.
    static func live() -> AppDependencies {
        let config = SupabaseConfig.fromBundle()
        let client = makeDevetSupabase(config)
        return AppDependencies(
            config: config, auth: SupabaseAuthRepository(client: client), account: SupabaseAccountRepository(client: client),
            connectivity: Connectivity(), language: SystemAppLanguage()
        )
    }

    static let preview = AppDependencies(
        config: SupabaseConfig(url: "", anonKey: "", publicBaseURL: "https://devet.example"),
        auth: SupabaseAuthRepository(client: nil), account: SupabaseAccountRepository(client: nil),
        connectivity: .fixed(true), language: SystemAppLanguage()
    )

    /// Legal pages on the guest site, in the UI language (web/public/legal; privacy arrives with T50).
    var termsURL: URL? { legalURL("terms") }
    var privacyURL: URL? { legalURL("privacy") }

    private func legalURL(_ page: String) -> URL? {
        var base = config.publicBaseURL
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: "\(base)/legal/\(page)/\(language.effective).html")
    }
}
