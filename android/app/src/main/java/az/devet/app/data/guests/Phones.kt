package az.devet.app.data.guests

import java.text.Normalizer

/**
 * Phone numbers → E.164 (spec/test-vectors/README.md#phones, cases: phones.json, JS reference:
 * tools/test-vectors/reference.mjs). [mobilePrefixes] comes from phones.json → `az_mobile_prefixes`.
 */
class Phones(private val mobilePrefixes: Set<String>) {
    sealed interface Result {
        data class Ok(val e164: String) : Result
        /** `empty`, `invalid` or `not_mobile`. */
        data class Error(val code: String) : Result
    }

    fun normalize(input: String?): Result {
        var s = Normalizer.normalize(input.orEmpty(), Normalizer.Form.NFKC).trim().replace(CLEAN, "")
        if (s.isEmpty()) return Result.Error("empty")
        if (!DIGITS.matches(s)) return Result.Error("invalid")
        if (s.startsWith("00")) s = "+" + s.drop(2)

        val e164 = when {
            s.startsWith("+") -> if (INTL.matches(s)) s else return Result.Error("invalid")
            AZ_FULL.matches(s) -> "+$s"
            AZ_TRUNK.matches(s) -> "+994" + s.drop(1)
            AZ_SHORT.matches(s) -> "+994$s"
            else -> return Result.Error("invalid")
        }
        if (e164.startsWith("+994")) {
            val national = e164.drop(4)
            if (national.length != 9) return Result.Error("invalid")
            if (national.take(2) !in mobilePrefixes) return Result.Error("not_mobile")
        }
        return Result.Ok(e164)
    }

    private companion object {
        val CLEAN = Regex("""[\s \-.()]""")
        val DIGITS = Regex("""^\+?\d+$""")
        val INTL = Regex("""^\+[1-9]\d{7,14}$""")
        val AZ_FULL = Regex("""^994\d{9}$""")
        val AZ_TRUNK = Regex("""^0\d{9}$""")
        val AZ_SHORT = Regex("""^[1-9]\d{8}$""")
    }
}
