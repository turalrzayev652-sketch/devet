package az.devet.app.data.guests

import org.xml.sax.Attributes
import org.xml.sax.helpers.DefaultHandler
import java.io.InputStream
import java.util.zip.ZipInputStream
import javax.xml.parsers.SAXParserFactory

/**
 * Minimal `.xlsx` reader: the first worksheet as rows of cells (text, number or empty). Enough for a guest list;
 * no dependency on Apache POI (which would add megabytes). Formulas give their cached value.
 */
object XlsxReader {
    class NotXlsx : Exception("not an xlsx file")

    fun read(input: InputStream): List<List<ExcelRules.Cell>> {
        val entries = mutableMapOf<String, ByteArray>()
        ZipInputStream(input).use { zip ->
            while (true) {
                val e = zip.nextEntry ?: break
                if (!e.isDirectory && e.name.startsWith("xl/")) entries[e.name] = zip.readLimited()
            }
        }
        val workbook = entries["xl/workbook.xml"] ?: throw NotXlsx()
        val shared = entries["xl/sharedStrings.xml"]?.let(::sharedStrings).orEmpty()
        val sheet = entries[firstSheetPath(workbook, entries["xl/_rels/workbook.xml.rels"])] ?: entries["xl/worksheets/sheet1.xml"] ?: throw NotXlsx()
        return rows(sheet, shared)
    }

    /** Guards against zip bombs: a guest list never needs more than a few megabytes per part. */
    private fun ZipInputStream.readLimited(limit: Int = 20 * 1024 * 1024): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(64 * 1024)
        while (true) {
            val n = read(buffer)
            if (n < 0) break
            out.write(buffer, 0, n)
            if (out.size() > limit) throw NotXlsx()
        }
        return out.toByteArray()
    }

    private fun parse(bytes: ByteArray, handler: DefaultHandler) {
        val factory = SAXParserFactory.newInstance().apply { isNamespaceAware = true }
        // No external entities in an untrusted file.
        runCatching { factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true) }
        factory.newSAXParser().parse(bytes.inputStream(), handler)
    }

    private fun firstSheetPath(workbook: ByteArray, rels: ByteArray?): String? {
        var rid: String? = null
        parse(workbook, object : DefaultHandler() {
            override fun startElement(uri: String?, local: String, q: String?, a: Attributes) {
                if (local == "sheet" && rid == null) {
                    rid = (0 until a.length).firstOrNull { a.getLocalName(it) == "id" }?.let { a.getValue(it) }
                }
            }
        })
        if (rid == null || rels == null) return null
        var target: String? = null
        parse(rels, object : DefaultHandler() {
            override fun startElement(uri: String?, local: String, q: String?, a: Attributes) {
                if (local == "Relationship" && a.getValue("Id") == rid) target = a.getValue("Target")
            }
        })
        return target?.let { if (it.startsWith("/")) it.drop(1) else "xl/" + it.removePrefix("./") }
    }

    private fun sharedStrings(bytes: ByteArray): List<String> {
        val result = mutableListOf<String>()
        parse(bytes, object : DefaultHandler() {
            val text = StringBuilder()
            var inSi = false
            var inT = false
            var inPhonetic = false
            override fun startElement(uri: String?, local: String, q: String?, a: Attributes) {
                when (local) {
                    "si" -> { inSi = true; text.clear() }
                    "rPh" -> inPhonetic = true
                    "t" -> inT = inSi && !inPhonetic
                }
            }
            override fun endElement(uri: String?, local: String, q: String?) {
                when (local) {
                    "si" -> { result += text.toString(); inSi = false }
                    "rPh" -> inPhonetic = false
                    "t" -> inT = false
                }
            }
            override fun characters(ch: CharArray, start: Int, length: Int) { if (inT) text.appendRange(ch, start, start + length) }
        })
        return result
    }

    private fun rows(bytes: ByteArray, shared: List<String>): List<List<ExcelRules.Cell>> {
        val rows = sortedMapOf<Int, MutableMap<Int, ExcelRules.Cell>>()
        parse(bytes, object : DefaultHandler() {
            var row = 0
            var col = 0
            var type = ""
            val value = StringBuilder()
            var inValue = false
            override fun startElement(uri: String?, local: String, q: String?, a: Attributes) {
                when (local) {
                    "row" -> row = a.getValue("r")?.toIntOrNull() ?: (row + 1)
                    "c" -> {
                        val ref = a.getValue("r")
                        col = ref?.let(::columnIndex) ?: (col + 1)
                        type = a.getValue("t") ?: "n"
                        value.clear()
                    }
                    "v", "t" -> inValue = true
                }
            }
            override fun endElement(uri: String?, local: String, q: String?) {
                when (local) {
                    "v", "t" -> inValue = false
                    "c" -> {
                        val raw = value.toString()
                        val cell = when {
                            raw.isEmpty() -> ExcelRules.Cell.Empty
                            type == "s" -> ExcelRules.Cell.Text(shared.getOrElse(raw.trim().toIntOrNull() ?: -1) { "" })
                            type == "inlineStr" || type == "str" -> ExcelRules.Cell.Text(raw)
                            type == "b" -> ExcelRules.Cell.Text(if (raw == "1") "true" else "false")
                            type == "e" -> ExcelRules.Cell.Empty
                            else -> raw.toDoubleOrNull()?.let { ExcelRules.Cell.Number(it) } ?: ExcelRules.Cell.Text(raw)
                        }
                        rows.getOrPut(row) { mutableMapOf() }[col] = cell
                    }
                }
            }
            override fun characters(ch: CharArray, start: Int, length: Int) { if (inValue) value.appendRange(ch, start, start + length) }
        })
        // Rows keep their position (an empty row in the middle stays empty, then is skipped by the rules).
        val last = rows.keys.maxOrNull() ?: return emptyList()
        return (1..last).map { r ->
            val cells = rows[r].orEmpty()
            val width = (cells.keys.maxOrNull() ?: -1) + 1
            (0 until width).map { cells[it] ?: ExcelRules.Cell.Empty }
        }
    }

    /** "C12" → 2 (0-based). */
    private fun columnIndex(ref: String): Int = ref.takeWhile { it.isLetter() }.fold(0) { acc, ch -> acc * 26 + (ch.uppercaseChar() - 'A' + 1) } - 1
}
