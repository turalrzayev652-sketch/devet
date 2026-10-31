package az.devet.app.data.guests

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.text.Normalizer

/**
 * `.xlsx` import rules (spec/test-vectors/README.md#excel, cases: excel.json, JS reference:
 * tools/test-vectors/reference.mjs). Column aliases and allowed values come from excel.json itself.
 */
class ExcelRules(
    /** Fields in excel.json order: name, phone, salutation, invited_count, with_family, side, table_no. */
    val fields: List<String>,
    private val aliases: Map<String, String>,
    private val values: Map<String, Map<String, String>>,
    val phones: Phones,
) {
    /** A cell: text, number or empty. */
    sealed interface Cell {
        data class Text(val value: String) : Cell
        data class Number(val value: Double) : Cell
        data object Empty : Cell
    }

    sealed interface RowResult {
        data object Skipped : RowResult
        data class Ok(val guest: NewGuest) : RowResult
        data class Errors(val codes: List<String>) : RowResult
    }

    data class Warning(val row: Int, val firstRow: Int)

    /** Header row → field → column index; null when no column maps to `name` (`name_column_missing`). */
    fun mapHeaders(headers: List<String>): Map<String, Int>? = mapHeadersPartial(headers).takeIf { "name" in it }

    /** Same mapping without requiring `name` — the column screen starts from it when the name column is unknown. */
    fun mapHeadersPartial(headers: List<String>): Map<String, Int> {
        val result = linkedMapOf<String, Int>()
        headers.forEachIndexed { i, h -> aliases[normalizeHeader(h)]?.let { field -> result.putIfAbsent(field, i) } }
        return result
    }

    fun parseRow(row: Map<String, Cell>): RowResult {
        if (row.values.all(::isEmpty)) return RowResult.Skipped
        val errors = mutableListOf<String>()
        var name = ""
        var phone: String? = null
        var salutation = Salutation.None
        var count = 1
        var family = false
        var side = Side.None
        var table: String? = null
        for (field in fields) {
            val raw = row[field] ?: Cell.Empty
            when (field) {
                "name" -> { name = asText(raw); if (name.isEmpty()) errors += "name_missing" }
                "phone" -> if (!isEmpty(raw)) {
                    val input = if (raw is Cell.Number) raw.value.toLong().toString() else asText(raw)
                    when (val r = phones.normalize(input)) {
                        is Phones.Result.Ok -> phone = r.e164
                        is Phones.Result.Error -> errors += if (r.code == "not_mobile") "phone_not_mobile" else "phone_invalid"
                    }
                }
                "salutation" -> {
                    val v = if (isEmpty(raw)) "none" else lookup("salutation", raw)
                    if (v == null) errors += "salutation_invalid" else salutation = Salutation.of(v)
                }
                "invited_count" -> {
                    val n = parseCount(raw)
                    if (n == null) errors += "invited_count_invalid" else count = n
                }
                "with_family" -> {
                    val v = if (isEmpty(raw)) "false" else lookup("boolean", raw)
                    if (v == null) errors += "with_family_invalid" else family = v == "true"
                }
                "side" -> {
                    val v = if (isEmpty(raw)) "none" else lookup("side", raw)
                    if (v == null) errors += "side_invalid" else side = Side.of(v)
                }
                "table_no" -> if (!isEmpty(raw)) {
                    val t = asText(raw)
                    if (t.length > GuestRules.MAX_TABLE) errors += "table_no_invalid" else table = t
                }
            }
        }
        return if (errors.isNotEmpty()) RowResult.Errors(errors)
        else RowResult.Ok(NewGuest(name, salutation, family, count, phone, side, table))
    }

    /** Same normalised phone in a later row → `duplicate_phone` warning (1-based data rows). */
    fun duplicateWarnings(results: List<RowResult>): List<Warning> {
        val seen = mutableMapOf<String, Int>()
        val warnings = mutableListOf<Warning>()
        results.forEachIndexed { i, r ->
            val phone = (r as? RowResult.Ok)?.guest?.phoneE164 ?: return@forEachIndexed
            val first = seen[phone]
            if (first != null) warnings += Warning(i + 1, first) else seen[phone] = i + 1
        }
        return warnings
    }

    private fun lookup(table: String, raw: Cell): String? {
        val v = normalizeValue(asText(raw))
        return values.getValue(table).entries.firstOrNull { it.key == v }?.value
    }

    private fun parseCount(raw: Cell): Int? {
        if (isEmpty(raw)) return 1
        val n = when (raw) {
            is Cell.Number -> raw.value
            is Cell.Text -> raw.value.trim().toDoubleOrNull() ?: return null
            Cell.Empty -> return 1
        }
        if (n != kotlin.math.floor(n)) return null
        return n.toInt().takeIf { GuestRules.countOk(it) }
    }

    companion object {
        fun isEmpty(c: Cell) = c is Cell.Empty || (c is Cell.Text && c.value.isBlank())

        /** Numbers become text the way JavaScript prints them: 5.0 → "5", 2.5 → "2.5". */
        fun asText(c: Cell): String = when (c) {
            is Cell.Text -> c.value.trim()
            is Cell.Number -> if (c.value == kotlin.math.floor(c.value) && !c.value.isInfinite()) c.value.toLong().toString() else c.value.toString()
            Cell.Empty -> ""
        }

        fun fold(text: String): String {
            val lower = Normalizer.normalize(text, Normalizer.Form.NFKC).lowercase().replace('ı', 'i').replace('ə', 'e')
            return Normalizer.normalize(lower, Normalizer.Form.NFD).replace(MARKS, "").replace(SPACES, " ").trim()
        }

        fun normalizeHeader(text: String) = fold(text).replace(NON_WORD, " ").trim()
        fun normalizeValue(text: String) = fold(text)

        private val MARKS = Regex("""\p{M}+""")
        private val SPACES = Regex("""\s+""")
        private val NON_WORD = Regex("""[^\p{L}\p{N}]+""")

        /** Builds the rules from excel.json and phones.json text. */
        fun fromJson(excelJson: String, phonesJson: String): ExcelRules {
            val excel = Json.parseToJsonElement(excelJson).jsonObject
            val columns = excel.getValue("columns").jsonObject
            val aliases = mutableMapOf<String, String>()
            for ((field, spec) in columns) {
                for (a in spec.jsonObject.getValue("aliases").jsonArray) aliases.putIfAbsent(normalizeHeader(a.jsonPrimitive.content), field)
            }
            val values = excel.getValue("values").jsonObject.mapValues { (_, table) ->
                val map = mutableMapOf<String, String>()
                for ((key, list) in (table as JsonObject)) for (alias in list.jsonArray) map.putIfAbsent(normalizeValue(alias.jsonPrimitive.content), key)
                map.toMap()
            }
            return ExcelRules(columns.keys.toList(), aliases, values, phonesFromJson(phonesJson))
        }

        fun phonesFromJson(phonesJson: String) =
            Phones(Json.parseToJsonElement(phonesJson).jsonObject.getValue("az_mobile_prefixes").jsonArray.map { it.jsonPrimitive.content }.toSet())
    }
}
