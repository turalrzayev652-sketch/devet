package az.devet.app.data.guests

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Guest's name as the invitation shows it, in the guest's language (api.md §0.4, PRODUCT.md §8):
 * `salutation.*` + `salutation.family`, and the greeting line `greeting.*`. Forms come from spec/i18n/invite.json
 * (copied into the app at build time) — the same forms the server and the guest page use.
 */
class DisplayNames(private val forms: Map<String, Map<String, String>>) {

    fun displayName(name: String, salutation: Salutation, withFamily: Boolean, lang: String): String {
        val base = form("salutation.${salutation.key}", lang).replace("{name}", name.trim())
        return if (withFamily) form("salutation.family", lang).replace("{display}", base) else base
    }

    /** "Hörmətli Elçin müəllim və ailəsi!" — the preview under the guest form (screens.md §6.1). */
    fun greeting(name: String, salutation: Salutation, withFamily: Boolean, lang: String): String {
        val key = if (withFamily) "greeting.family" else "greeting.${salutation.key}"
        return form(key, lang).replace("{display_name}", displayName(name, salutation, withFamily, lang))
    }

    private fun form(key: String, lang: String) = forms[key]?.let { it[lang] ?: it["az"] } ?: "{name}"

    companion object {
        fun fromJson(inviteJson: String) = DisplayNames(
            Json.parseToJsonElement(inviteJson).jsonObject
                .filterKeys { it.startsWith("salutation.") || it.startsWith("greeting.") }
                .mapValues { (_, v) -> v.jsonObject.mapValues { it.value.jsonPrimitive.content } },
        )
    }
}
