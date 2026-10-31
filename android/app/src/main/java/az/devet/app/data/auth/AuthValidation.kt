package az.devet.app.data.auth

/** Form rules from spec/screens.md §1 (and §15.1: password ≥ 6). The iOS app applies the same rules. */
object AuthValidation {
    const val MIN_PASSWORD = 6
    const val MAX_NAME = 80

    private val EMAIL = Regex("""^[^\s@]+@[^\s@]+\.[^\s@]+$""")

    fun isEmail(value: String) = EMAIL.matches(value.trim())

    fun isPassword(value: String) = value.length >= MIN_PASSWORD

    fun isName(value: String) = value.trim().length in 1..MAX_NAME

    fun canSignIn(email: String, password: String) = isEmail(email) && password.isNotEmpty()

    fun canRegister(name: String, email: String, password: String, repeat: String, termsAccepted: Boolean) =
        isName(name) && isEmail(email) && isPassword(password) && password == repeat && termsAccepted

    fun canSetPassword(password: String, repeat: String) = isPassword(password) && password == repeat
}
