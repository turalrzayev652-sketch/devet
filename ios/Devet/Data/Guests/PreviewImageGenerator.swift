import UIKit

/// UIGraphicsImageRenderer-ə əsasən 1200×630 adlı dəvət şəkli yaratmaq (screens.md §8a, PRODUCT §5).
class PreviewImageGenerator {
    static let width: CGFloat = 1200
    static let height: CGFloat = 630
    static let jpegQuality: CGFloat = 0.85
    static let maxBytes = 80 * 1024

    /// Qonaq üçün preview JPEG yaradır: display_name + "lang.invite_text" (qonağın dilində).
    /// Fon rəngi template.customization.colors["--dv-color-bg"] (hex, məs. "#faf7f2") və ya defolt.
    func generate(params: PreviewParams) -> PreviewImage {
        let bgColorStr = params.templateBgColor ?? "#faf7f2"
        let bgColor = UIColor(hex: bgColorStr) ?? UIColor(hex: "#faf7f2")!

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: Self.width, height: Self.height))
        let image = renderer.image { context in
            // Background
            bgColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: Self.width, height: Self.height))

            // Display name (serif, large, centered)
            let nameFont = UIFont(name: "Georgia", size: 56) ?? UIFont.systemFont(ofSize: 56, weight: .semibold)
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: contrastColor(bgColor)
            ]
            let name = params.displayName.prefix(80)
            let nameStr = NSAttributedString(string: String(name), attributes: nameAttrs)
            let nameSize = nameStr.size()
            let nameX = (Self.width - nameSize.width) / 2
            let nameY: CGFloat = 120
            nameStr.draw(at: CGPoint(x: nameX, y: nameY))

            // Invite text (smaller, bottom)
            let inviteText = inviteTextByLang[params.lang] ?? inviteTextByLang["az"]!
            let inviteFont = UIFont.systemFont(ofSize: 36, weight: .regular)
            let inviteAttrs: [NSAttributedString.Key: Any] = [
                .font: inviteFont,
                .foregroundColor: contrastColor(bgColor).withAlphaComponent(0.8)
            ]
            let inviteStr = NSAttributedString(string: inviteText, attributes: inviteAttrs)
            let inviteSize = inviteStr.size()
            let inviteX = (Self.width - inviteSize.width) / 2
            let inviteY = nameY + 100
            inviteStr.draw(at: CGPoint(x: inviteX, y: inviteY))

            // Watermark (code, small, bottom-right)
            let codeFont = UIFont(name: "Courier New", size: 20) ?? UIFont.monospacedSystemFont(ofSize: 20, weight: .regular)
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: codeFont,
                .foregroundColor: contrastColor(bgColor).withAlphaComponent(0.5)
            ]
            let codeStr = NSAttributedString(string: params.code, attributes: codeAttrs)
            let codeSize = codeStr.size()
            codeStr.draw(at: CGPoint(x: Self.width - codeSize.width - 20, y: Self.height - codeSize.height - 20))
        }

        // JPEG compression with size management
        var quality: CGFloat = Self.jpegQuality
        var bytes = image.jpegData(compressionQuality: quality)!
        while bytes.count > Self.maxBytes && quality > 0.5 {
            quality -= 0.05
            bytes = image.jpegData(compressionQuality: quality)!
        }

        return PreviewImage(image: image, bytes: bytes, code: params.code)
    }

    /// Fon rənginə uyğun ziddiyyətli mətn rəngi seç (siyah/ağ).
    private func contrastColor(_ bgColor: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        bgColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Luminance (WCAG): 0.2126 * R + 0.7152 * G + 0.0722 * B
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.5 ? .black : .white
    }
}

extension UIColor {
    /// Hex string-dən UIColor yaradır (məs. "#faf7f2" və ya "faf7f2").
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespaces)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }

        guard hexSanitized.count == 6 else { return nil }
        let scanner = Scanner(string: hexSanitized)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
