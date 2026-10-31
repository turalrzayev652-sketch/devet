package az.devet.app.guests

import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.ExcelRules
import az.devet.app.data.guests.Phones
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.XlsxReader
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** spec/test-vectors phones.json and excel.json, case by case (shared with iOS and the JS reference). */
class GuestRulesTest {
    private val root = File(System.getProperty("devet.repoRoot") ?: error("devet.repoRoot not set"))
    private fun text(path: String) = File(root, path).readText()
    private val rules = ExcelRules.fromJson(text("spec/test-vectors/excel.json"), text("spec/test-vectors/phones.json"))
    private val excel = Json.parseToJsonElement(text("spec/test-vectors/excel.json")).jsonObject

    @Test
    fun phoneVectors() {
        val phones: Phones = ExcelRules.phonesFromJson(text("spec/test-vectors/phones.json"))
        val cases = Json.parseToJsonElement(text("spec/test-vectors/phones.json")).jsonObject.getValue("cases").jsonArray
        assertTrue(cases.size >= 40)
        for (c in cases.map { it.jsonObject }) {
            val input = c.getValue("input").jsonPrimitive.content
            val expected = c["expected"]?.takeUnless { it is JsonNull }?.jsonPrimitive?.content
            val result = phones.normalize(input)
            if (expected != null) assertEquals(input, Phones.Result.Ok(expected), result)
            else assertEquals(input, Phones.Result.Error(c.getValue("error").jsonPrimitive.content), result)
        }
    }

    @Test
    fun headerVectors() {
        for (c in excel.getValue("header_cases").jsonArray.map { it.jsonObject }) {
            val headers = c.getValue("headers").jsonArray.map { it.jsonPrimitive.content }
            val expected = c["expected"]?.takeUnless { it is JsonNull }?.jsonObject?.mapValues { it.value.jsonPrimitive.int }
            assertEquals(headers.toString(), expected, rules.mapHeaders(headers))
        }
    }

    private fun cell(e: JsonElement?): ExcelRules.Cell = when {
        e == null || e is JsonNull -> ExcelRules.Cell.Empty
        e is JsonPrimitive && e.isString -> ExcelRules.Cell.Text(e.content)
        e is JsonPrimitive && e.doubleOrNull != null -> ExcelRules.Cell.Number(e.doubleOrNull!!)
        else -> ExcelRules.Cell.Text(e.toString())
    }

    private fun row(o: JsonObject) = o.mapValues { cell(it.value) }

    @Test
    fun rowVectors() {
        for (c in excel.getValue("row_cases").jsonArray.map { it.jsonObject }) {
            val input = c.getValue("row").jsonObject
            val result = rules.parseRow(row(input))
            when {
                c["skipped"]?.jsonPrimitive?.booleanOrNull == true -> assertEquals(input.toString(), ExcelRules.RowResult.Skipped, result)
                c["errors"] != null -> assertEquals(
                    input.toString(), ExcelRules.RowResult.Errors(c.getValue("errors").jsonArray.map { it.jsonPrimitive.content }), result,
                )
                else -> {
                    val e = c.getValue("expected").jsonObject
                    val g = (result as? ExcelRules.RowResult.Ok)?.guest ?: error("expected Ok for $input, got $result")
                    assertEquals(e.getValue("name").jsonPrimitive.content, g.name)
                    assertEquals(e["phone_e164"]?.takeUnless { it is JsonNull }?.jsonPrimitive?.content, g.phoneE164)
                    assertEquals(e.getValue("salutation").jsonPrimitive.content, g.salutation.key)
                    assertEquals(e.getValue("invited_count").jsonPrimitive.int, g.invitedCount)
                    assertEquals(e.getValue("with_family").jsonPrimitive.boolean, g.withFamily)
                    assertEquals(e.getValue("side").jsonPrimitive.content, g.side.key)
                    assertEquals(e["table_no"]?.takeUnless { it is JsonNull }?.jsonPrimitive?.content, g.tableNo)
                }
            }
        }
    }

    @Test
    fun fileVectors() {
        for (c in excel.getValue("file_cases").jsonArray.map { it.jsonObject }) {
            val rows = c.getValue("rows").jsonArray.map { row(it.jsonObject) }
            if (c["error"] != null) {
                assertTrue("no_rows", rows.isEmpty())
                continue
            }
            val warnings = rules.duplicateWarnings(rows.map(rules::parseRow))
            val expected = c.getValue("expected_warnings").jsonArray.map { w ->
                ExcelRules.Warning(w.jsonObject.getValue("row").jsonPrimitive.int, w.jsonObject.getValue("first_row").jsonPrimitive.int)
            }
            assertEquals(expected, warnings)
        }
    }

    @Test
    fun displayNamesFromInviteJson() {
        val names = DisplayNames.fromJson(text("spec/i18n/invite.json"))
        // PRODUCT.md §8 table.
        assertEquals("Elçin müəllim", names.displayName("Elçin", Salutation.Muellim, false, "az"))
        assertEquals("Mr. Elchin", names.displayName("Elchin", Salutation.Muellim, false, "en"))
        assertEquals("Leyla Hanım", names.displayName("Leyla", Salutation.Xanim, false, "tr"))
        assertEquals("Elçin муаллим с семьёй", names.displayName("Elçin", Salutation.Muellim, true, "ru"))
        assertEquals("Hörmətli Elçin müəllim və ailəsi!", names.greeting("Elçin", Salutation.Muellim, true, "az"))
        assertEquals("Уважаемая Leyla ханум!", names.greeting("Leyla", Salutation.Xanim, false, "ru"))
    }

    @Test
    fun xlsxSampleReadsAndImports() {
        val rows = File(root, "android/app/src/main/assets/sample/guests-sample.xlsx").inputStream().use(XlsxReader::read)
        val headers = rows.first().map(ExcelRules::asText)
        val mapping = rules.mapHeaders(headers)!!
        assertEquals(7, mapping.size)
        val parsed = rows.drop(1).map { r -> rules.parseRow(mapping.mapValues { (_, col) -> r.getOrElse(col) { ExcelRules.Cell.Empty } }) }
        assertTrue(parsed.toString(), parsed.all { it is ExcelRules.RowResult.Ok })
        val first = (parsed[0] as ExcelRules.RowResult.Ok).guest
        assertEquals("+994501234567", first.phoneE164)
        assertEquals(4, first.invitedCount)
        assertTrue(first.withFamily)
    }

    @Test
    fun xlsxWithSharedStringsAndGaps() {
        val shared = """<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Ad</t></si><si><t>Telefon</t></si><si><r><t>Elç</t></r><r><t>in</t></r></si></sst>"""
        val sheet = """<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
            <row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>
            <row r="3"><c r="A3" t="s"><v>2</v></c><c r="C3"><v>501234567</v></c></row></sheetData></worksheet>"""
        val wb = """<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="S" sheetId="1" r:id="rId7"/></sheets></workbook>"""
        val rels = """<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId7" Type="worksheet" Target="worksheets/data.xml"/></Relationships>"""
        val bytes = ByteArrayOutputStream().also { out ->
            ZipOutputStream(out).use { z ->
                for ((name, body) in listOf("xl/workbook.xml" to wb, "xl/_rels/workbook.xml.rels" to rels, "xl/sharedStrings.xml" to shared, "xl/worksheets/data.xml" to sheet)) {
                    z.putNextEntry(ZipEntry(name)); z.write(body.toByteArray()); z.closeEntry()
                }
            }
        }.toByteArray()
        val rows = XlsxReader.read(bytes.inputStream())
        assertEquals(3, rows.size)
        assertEquals(listOf(ExcelRules.Cell.Text("Ad"), ExcelRules.Cell.Empty, ExcelRules.Cell.Text("Telefon")), rows[0])
        assertTrue("empty middle row", rows[1].isEmpty())
        assertEquals(ExcelRules.Cell.Text("Elçin"), rows[2][0])
        assertEquals(ExcelRules.Cell.Number(501234567.0), rows[2][2])
    }

    /** TASKS.md T45: a 300-row Excel file is read and checked in under 5 seconds. */
    @Test
    fun threeHundredRowsUnderFiveSeconds() {
        val sheet = StringBuilder("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>")
        sheet.append("<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Ad</t></is></c><c r=\"B1\" t=\"inlineStr\"><is><t>Telefon</t></is></c><c r=\"C1\" t=\"inlineStr\"><is><t>Masa</t></is></c></row>")
        for (r in 2..301) {
            sheet.append("<row r=\"$r\"><c r=\"A$r\" t=\"inlineStr\"><is><t>Qonaq $r</t></is></c><c r=\"B$r\"><v>50${1000000 + r}</v></c><c r=\"C$r\"><v>${r % 30}</v></c></row>")
        }
        sheet.append("</sheetData></worksheet>")
        val bytes = ByteArrayOutputStream().also { out ->
            ZipOutputStream(out).use { z ->
                z.putNextEntry(ZipEntry("xl/workbook.xml")); z.write("<workbook/>".toByteArray()); z.closeEntry()
                z.putNextEntry(ZipEntry("xl/worksheets/sheet1.xml")); z.write(sheet.toString().toByteArray()); z.closeEntry()
            }
        }.toByteArray()
        val start = System.nanoTime()
        val rows = XlsxReader.read(bytes.inputStream())
        val mapping = rules.mapHeaders(rows.first().map(ExcelRules::asText))!!
        val parsed = rows.drop(1).map { r -> rules.parseRow(mapping.mapValues { (_, col) -> r.getOrElse(col) { ExcelRules.Cell.Empty } }) }
        rules.duplicateWarnings(parsed)
        val ms = (System.nanoTime() - start) / 1_000_000
        assertEquals(300, parsed.count { it is ExcelRules.RowResult.Ok })
        assertTrue("took $ms ms", ms < 5000)
    }

    @Test(expected = XlsxReader.NotXlsx::class)
    fun notAnXlsx() {
        XlsxReader.read("hello".byteInputStream())
    }

    @Test
    fun foldMatchesReadme() {
        assertEquals("ad soyad", ExcelRules.normalizeHeader("  AD SOYAD "))
        assertEquals("adi", ExcelRules.normalizeHeader("Adı"))
        assertEquals("nomre", ExcelRules.normalizeHeader("Nömrə"))
        assertNull(rules.mapHeaders(listOf("Telefon")))
    }
}
