package az.devet.app.guests

import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventDraft
import az.devet.app.data.guests.AddResult
import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.ExcelRules
import az.devet.app.data.guests.GuestPhone
import az.devet.app.data.guests.GuestRepository
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.NewGuest
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import az.devet.app.events.FakeEvents
import az.devet.app.ui.guests.ContactsViewModel
import az.devet.app.ui.guests.ExcelImportViewModel
import az.devet.app.ui.guests.ExcelStep
import az.devet.app.ui.guests.GuestContext
import az.devet.app.ui.guests.ManualGuestViewModel
import az.devet.app.ui.guests.PhoneIssue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

class FakeGuests : GuestRepository {
    var existing = listOf(GuestPhone("Elçin", "+994501234567"))
    var result: AddResult? = null
    val batches = mutableListOf<List<NewGuest>>()
    override suspend fun phones(eventId: String) = AuthResult.Ok(existing)
    override suspend fun count(eventId: String) = AuthResult.Ok(existing.size)
    override suspend fun add(eventId: String, guests: List<NewGuest>): AddResult {
        batches += guests
        return result ?: AddResult.Added(guests.size)
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class AddGuestViewModelsTest {
    private val root = File(System.getProperty("devet.repoRoot") ?: error("devet.repoRoot not set"))
    private val spec = GuestSpec(
        ExcelRules.fromJson(File(root, "spec/test-vectors/excel.json").readText(), File(root, "spec/test-vectors/phones.json").readText()),
        DisplayNames.fromJson(File(root, "spec/i18n/invite.json").readText()),
    )
    private val guests = FakeGuests()
    private val events = FakeEvents().apply { getResult = AuthResult.Ok(EventDraft(defaultLang = "ru")) }
    private fun ctx() = GuestContext("e1", guests, events)

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test
    fun manualSaveAndNextKeepsSideTableLanguage() {
        val vm = ManualGuestViewModel(ctx(), spec)
        assertEquals("event language for the preview", "ru", vm.state.value.eventLang)
        vm.edit { it.copy(name = "Leyla", salutation = Salutation.Xanim, phone = "055 111 22 33", side = Side.Bride, table = "7", lang = "az", count = 2) }
        vm.save(andNext = true)
        val sent = guests.batches.single().single()
        assertEquals(NewGuest("Leyla", Salutation.Xanim, false, 2, "+994551112233", Side.Bride, "7", "az"), sent)
        val f = vm.state.value.form
        assertEquals("", f.name)
        assertEquals(Salutation.None, f.salutation)
        assertEquals(Side.Bride, f.side)
        assertEquals("7", f.table)
        assertEquals("az", f.lang)
        assertEquals("Leyla xanım", vm.state.value.added)
    }

    @Test
    fun manualPhoneProblemsAndDuplicates() {
        val vm = ManualGuestViewModel(ctx(), spec)
        vm.edit { it.copy(name = "Tural", phone = "012 345 67 89") }
        assertEquals(PhoneIssue.NotMobile, vm.state.value.phoneIssue)
        assertFalse(vm.state.value.canSave)
        vm.edit { it.copy(phone = "12345") }
        assertEquals(PhoneIssue.Invalid, vm.state.value.phoneIssue)
        vm.edit { it.copy(phone = "+994 50 123 45 67") }
        assertEquals(PhoneIssue.None, vm.state.value.phoneIssue)
        assertEquals("duplicate is a warning only", "Elçin", vm.state.value.duplicateOf)
        assertTrue(vm.state.value.canSave)
        vm.edit { it.copy(phone = "") }
        assertTrue("phone is optional", vm.state.value.canSave)
    }

    @Test
    fun manualEmptyNameShowsError() {
        val vm = ManualGuestViewModel(ctx(), spec)
        vm.save(andNext = true)
        assertTrue(vm.state.value.nameError)
        assertTrue(guests.batches.isEmpty())
    }

    @Test
    fun manualLimitKeepsTheForm() {
        guests.result = AddResult.LimitExceeded(100)
        val vm = ManualGuestViewModel(ctx(), spec)
        vm.edit { it.copy(name = "Leyla") }
        vm.save(andNext = true)
        assertEquals(100, vm.state.value.limit?.limit)
        assertEquals("Leyla", vm.state.value.form.name)
    }

    @Test
    fun contactsWithoutMobileAreAddedWithoutPhone() {
        val vm = ContactsViewModel(ctx(), spec)
        vm.picked("Ana", "+994 12 345 67 89")
        vm.picked("Rəşad", "050-123-45-67")
        val (ana, resad) = vm.state.value.picked
        assertTrue(ana.noMobile)
        assertNull(ana.phoneE164)
        assertEquals("Elçin", resad.duplicateOf)
        vm.edit(resad.id) { it.copy(salutation = Salutation.Bey, count = 3) }
        vm.addAll()
        assertEquals(listOf(NewGuest("Ana"), NewGuest("Rəşad", Salutation.Bey, false, 3, "+994501234567")), guests.batches.single())
        assertTrue(vm.state.value.picked.isEmpty())
        assertEquals(2, vm.state.value.addedCount)
    }

    /** Minimal .xlsx with inline strings and numbers, for feeding the real reader. */
    private fun xlsx(rows: List<List<Any?>>): ByteArray {
        val sb = StringBuilder("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>")
        rows.forEachIndexed { r, row ->
            sb.append("<row r=\"${r + 1}\">")
            row.forEachIndexed { c, v ->
                val ref = "${'A' + c}${r + 1}"
                when (v) {
                    null, "" -> Unit
                    is Number -> sb.append("<c r=\"$ref\"><v>$v</v></c>")
                    else -> sb.append("<c r=\"$ref\" t=\"inlineStr\"><is><t>$v</t></is></c>")
                }
            }
            sb.append("</row>")
        }
        sb.append("</sheetData></worksheet>")
        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { z ->
            z.putNextEntry(java.util.zip.ZipEntry("xl/workbook.xml")); z.write("<workbook/>".toByteArray()); z.closeEntry()
            z.putNextEntry(java.util.zip.ZipEntry("xl/worksheets/sheet1.xml")); z.write(sb.toString().toByteArray()); z.closeEntry()
        }
        return out.toByteArray()
    }

    @Test
    fun excelMappingSummaryAndImport() {
        val vm = ExcelImportViewModel(ctx(), spec, UnconfinedTestDispatcher())
        val file = xlsx(listOf(
            listOf("Ad", "Telefon", "Qeyd"),
            listOf("Leyla", "0551112233", "x"),
            listOf("", "0551112244"),
            listOf("Kamran", 501234567),
            emptyList(),
            listOf("Ana", "0551112233"),
        ))
        vm.open("toy.xlsx") { file.inputStream() }
        val mapping = vm.state.value.step as ExcelStep.Mapping
        assertEquals(mapOf(0 to "name", 1 to "phone"), mapping.columns)
        assertEquals(5, mapping.rows.size)
        vm.toSummary()
        val s = vm.state.value.step as ExcelStep.Summary
        assertEquals(listOf("Leyla", "Kamran", "Ana"), s.guests.map { it.name })
        assertEquals("sheet row 3 (header is row 1)", 3, s.errors.single().sheetRow)
        assertEquals(listOf("name_missing"), s.errors.single().codes)
        assertEquals("Ana repeats Leyla's number; Kamran's is already in the event", 2, s.duplicates)

        guests.result = AddResult.LimitExceeded(100)
        vm.import()
        assertEquals(100, vm.state.value.limit?.limit)
        assertTrue("summary kept for a retry", vm.state.value.step is ExcelStep.Summary)

        guests.result = null
        vm.limitShown()
        vm.import()
        assertEquals(3, vm.state.value.addedCount)
        assertEquals(ExcelStep.Pick, vm.state.value.step)
        assertEquals(2, guests.batches.size)
        assertEquals("one request per import", 3, guests.batches.last().size)
    }

    @Test
    fun excelWithoutNameColumnLetsTheUserPickIt() {
        fun t(s: String) = ExcelRules.Cell.Text(s)
        val vm = ExcelImportViewModel(ctx(), spec)
        val mapping = vm.mappingFor("x.xlsx", listOf(listOf(t("Qonaqlar"), t("Telefon")), listOf(t("Leyla"), t("0551112233")))) as ExcelStep.Mapping
        assertFalse(mapping.hasName)
        assertEquals(mapOf(1 to "phone"), mapping.columns)
        assertEquals(ExcelStep.FileError(noRows = true), vm.mappingFor("x.xlsx", listOf(listOf(t("Ad")))))
        assertEquals(ExcelStep.FileError(noRows = false), vm.mappingFor("x.xlsx", null))
    }
}
