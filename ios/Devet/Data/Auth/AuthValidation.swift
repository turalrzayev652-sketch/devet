import Foundation

/// Form rules from spec/screens.md §1 (and §15.1: password ≥ 6). Same rules as Android `AuthValidation`.
enum AuthValidation {
    static let minPassword = 6
    static let maxName = 80

    private static let email = try! NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#)

    static func isEmail(_ value: String) -> Bool {
        let v = value.trimmingCharacters(in: .whitespaces)
        return email.firstMatch(in: v, range: NSRange(v.startIndex..., in: v)) != nil
    }

    static func isPassword(_ value: String) -> Bool { value.count >= minPassword }

    static func isName(_ value: String) -> Bool { (1...maxName).contains(value.trimmingCharacters(in: .whitespaces).count) }

    static func canSignIn(email: String, password: String) -> Bool { isEmail(email) && !password.isEmpty }

    static func canRegister(name: String, email: String, password: String, repeat: String, termsAccepted: Bool) -> Bool {
        isName(name) && isEmail(email) && isPassword(password) && password == `repeat` && termsAccepted
    }

    static func canSetPassword(_ password: String, repeat: String) -> Bool { isPassword(password) && password == `repeat` }

    /// Shown only once the repeat is at least as long as the password (same as Android).
    static func mismatch(_ password: String, _ repeat: String) -> Bool {
        !`repeat`.isEmpty && `repeat`.count >= password.count && `repeat` != password
    }
}
