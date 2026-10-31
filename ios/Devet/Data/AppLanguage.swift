import Foundation
import UIKit

/// App language on iOS: chosen in Settings → Devet → Language (owner's decision 2026-10-31, Apple's per-app setting).
/// The app only reads it and opens that settings page.
protocol AppLanguage {
    /// Language the UI shows now (az, ru, en or tr).
    var effective: String { get }
    func openSystemSettings()
}

struct SystemAppLanguage: AppLanguage {
    static let supported = ["az", "ru", "en", "tr"]

    var effective: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "az"
        return Self.supported.contains(lang) ? lang : "az"
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
