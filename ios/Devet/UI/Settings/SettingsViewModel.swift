import Foundation

/// Screen [12b] (spec/screens.md §12b). Sign-out and deletion end the session; AppModel then shows sign-in.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var email: String
    @Published private(set) var savedName = ""
    @Published var name = "" {
        didSet {
            if name.count > AuthValidation.maxName { name = String(name.prefix(AuthValidation.maxName)) }
            saved = false; error = nil
        }
    }
    @Published private(set) var loading = true
    @Published private(set) var saving = false
    @Published private(set) var saved = false
    @Published private(set) var error: AuthFailure?
    @Published var deleteDialog = false
    @Published var deleteConfirm = "" { didSet { deleteFailed = false } }
    @Published private(set) var deleting = false
    @Published private(set) var deleteFailed = false

    private let account: any AccountRepository
    private let auth: any AuthRepository
    let language: any AppLanguage

    init(account: any AccountRepository, auth: any AuthRepository, language: any AppLanguage) {
        self.account = account
        self.auth = auth
        self.language = language
        email = auth.currentEmail ?? ""
    }

    var canSaveName: Bool { AuthValidation.isName(name) && name.trimmed != savedName && !saving }
    /// The e-mail must be typed to confirm deletion (screens.md §12b).
    var canDelete: Bool { !email.isEmpty && deleteConfirm.trimmed.caseInsensitiveCompare(email) == .orderedSame && !deleting }

    func load() async {
        loading = true; error = nil
        let result = await account.profile()
        loading = false
        switch result {
        case let .success(profile):
            savedName = profile.displayName ?? ""
            name = savedName
            saved = false
            if let mail = profile.email { email = mail }
            // The language is chosen in iOS Settings; keep profiles.ui_lang equal to what the UI shows.
            if profile.uiLang != language.effective { _ = await account.updateLanguage(language.effective) }
        case let .failure(e):
            error = e
        }
    }

    func saveName() async {
        guard canSaveName else { return }
        saving = true; error = nil
        let newName = name.trimmed
        let result = await account.updateName(newName)
        saving = false
        switch result {
        case .success:
            savedName = newName
            name = newName
            saved = true
        case let .failure(e):
            error = e
        }
    }

    func signOut() async { await auth.signOut() }

    func openDelete() {
        deleteConfirm = ""
        deleteFailed = false
        deleteDialog = true
    }

    func deleteAccount() async {
        guard canDelete else { return }
        deleting = true; deleteFailed = false
        let result = await account.deleteAccount()
        switch result {
        case .success:
            await auth.signOut()
            deleting = false
            deleteDialog = false
        case .failure(.unauthorized):
            await auth.signOut()
            deleting = false
        case .failure:
            deleting = false
            deleteFailed = true
        }
    }
}
