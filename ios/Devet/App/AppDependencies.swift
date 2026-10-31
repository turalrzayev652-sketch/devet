import Foundation
import Supabase

/// App-wide services, passed down as an environment object (the iOS counterpart of the Android Koin module).
@MainActor
final class AppDependencies: ObservableObject {
    let config: SupabaseConfig
    let auth: any AuthRepository
    let account: any AccountRepository
    let events: any EventRepository
    let guests: any GuestRepository
    /// Rules from /spec bundled at build time; the app cannot work without them.
    let guestSpec: GuestSpec = try! GuestSpec.load()
    let archive: any ArchiveStore
    let connectivity: Connectivity
    let language: any AppLanguage

    init(
        config: SupabaseConfig, auth: any AuthRepository, account: any AccountRepository, events: any EventRepository,
        guests: any GuestRepository, archive: any ArchiveStore = DefaultsArchiveStore(), connectivity: Connectivity, language: any AppLanguage
    ) {
        self.guests = guests
        self.config = config
        self.auth = auth
        self.account = account
        self.events = events
        self.archive = archive
        self.connectivity = connectivity
        self.language = language
    }

    /// Without backend settings the client is nil and repositories report `AuthFailure.notConfigured`.
    static func live() -> AppDependencies {
        let config = SupabaseConfig.fromBundle()
        #if DEBUG
        // Demo mode (debug builds only): launch with `-DevetDemo YES` to try screens without Supabase.
        if UserDefaults.standard.bool(forKey: "DevetDemo") {
            return AppDependencies(
                config: config, auth: DemoAuth(), account: DemoAccount(), events: DemoEvents(), guests: DemoGuests(),
                connectivity: Connectivity(), language: SystemAppLanguage()
            )
        }
        #endif
        let client = makeDevetSupabase(config)
        return AppDependencies(
            config: config, auth: SupabaseAuthRepository(client: client), account: SupabaseAccountRepository(client: client),
            events: SupabaseEventRepository(client: client), guests: SupabaseGuestRepository(client: client),
            connectivity: Connectivity(), language: SystemAppLanguage()
        )
    }

    static let preview = AppDependencies(
        config: SupabaseConfig(url: "", anonKey: "", publicBaseURL: "https://devet.example"),
        auth: SupabaseAuthRepository(client: nil), account: SupabaseAccountRepository(client: nil),
        events: SupabaseEventRepository(client: nil), guests: SupabaseGuestRepository(client: nil),
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
