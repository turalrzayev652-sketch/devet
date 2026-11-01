import UIKit

/// Qonaq üçün adlı önizləmə şəkli: 1200×630 JPEG (bax screens.md §8a, design.md).
struct PreviewImage: Identifiable {
    let image: UIImage  // 1200×630, RGB
    let bytes: Data     // JPEG, ≤ 80 KB
    let code: String    // guests.code, path = previews/<code>.jpg

    var id: String { code }
}

/// Şəkil yaratmaq üçün parametrlər.
struct PreviewParams {
    let displayName: String     // "Elçin müəllim və ailəsi"
    let code: String
    let lang: String            // qonağın dili (az/ru/en/tr)
    let templateBgColor: String? // hex rəngi, məs. "#faf7f2"

    init(displayName: String, code: String, lang: String, templateBgColor: String? = nil) {
        precondition(!displayName.trimmingCharacters(in: .whitespaces).isEmpty, "displayName must not be blank")
        precondition(!code.isEmpty, "code must not be empty")
        self.displayName = displayName
        self.code = code
        self.lang = lang
        self.templateBgColor = templateBgColor
    }
}

/// Hər dildə "sizi dəvət edirik" metni.
let inviteTextByLang: [String: String] = [
    "az": "sizi dəvətində bəşər",
    "ru": "приглашают вас",
    "en": "invite you to",
    "tr": "sizi davetiyelere çağırıyor"
]
