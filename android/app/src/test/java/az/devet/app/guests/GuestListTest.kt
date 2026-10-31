package az.devet.app.guests

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventDraft
import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.ExcelRules
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.GuestStatus
import az.devet.app.data.guests.NewGuest
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import az.devet.app.data.guests.SupabaseGuestListRepository
import az.devet.app.data.guests.guestChanges
import az.devet.app.events.FakeEvents
import az.devet.app.ui.guests.GuestFilter
import az.devet.app.ui.guests.GuestListViewModel
import az.devet.app.ui.guests.GuestMessage
import az.devet.app.ui.guests.LimitLevel
import az.devet.app.ui.guests.limitLevel
import az.devet.app.ui.guests.searchMatches
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

private fun guest(
    id: String, name: String, side: Side = Side.None, table: String? = null, phone: String? = null,
    rsvp: String = "pending", sent: Boolean = false, opened: Boolean = false, count: Int = 0,
) = Guest(id, "C$id", Salutation.None, name, false, 1, phone, side, table, null, if (sent) "t" else null, if (opened) "t" else null, rsvp, count)

class FakeGuestList : GuestListRepository {
    var guests = listOf(
        guest("1", "Elçin", Side.Groom, "12", "+994501234567", rsvp = "yes", sent = true, count = 4),
        guest("2", "Leyla", Side.Bride, "7", sent = true, opened = true),
        guest("3", "Rəşad", Side.Groom, rsvp = "no", sent = true),
        guest("4", "Nərmin", Side.Bride, sent = true),
        guest("5", "Kamran"),
    )
    var listResult: AuthResult<List<Guest>>? = null
    var limit: Int? = 100
    var result: AuthResult<Unit> = AuthResult.Ok(Unit)
    val calls = mutableListOf<String>()
    var lastUpdate: Pair<NewGuest, NewGuest>? = null

    override suspend fun list(eventId: String) = listResult ?: AuthResult.Ok(guests)
    override suspend fun limit(eventId: String) = AuthResult.Ok(limit)
    override suspend fun update(id: String, before: NewGuest, after: NewGuest) = result.also { calls += "update:$id"; lastUpdate = before to after }
    override suspend fun bulkUpdate(ids: List<String>, column: String, value: String?) = result.also { calls += "bulk:$column=$value:${ids.sorted()}" }
    override suspend fun delete(ids: List<String>) = result.also { calls += "delete:${ids.sorted()}" }
}

@OptIn(ExperimentalCoroutinesApi::class)
class GuestListTest {
    private val root = File(System.getProperty("devet.repoRoot") ?: error("devet.repoRoot not set"))
    private val spec = GuestSpec(
        ExcelRules.fromJson(File(root, "spec/test-vectors/excel.json").readText(), File(root, "spec/test-vectors/phones.json").readText()),
        DisplayNames.fromJson(File(root, "spec/i18n/invite.json").readText()),
    )
    private val repo = FakeGuestList()
    private val events = FakeEvents().apply { getResult = AuthResult.Ok(EventDraft(defaultLang = "ru")) }

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test
    fun statusFollowsDesignRules() {
        assertEquals(GuestStatus.Coming, guest("a", "A", rsvp = "yes").status)
        assertEquals(GuestStatus.Declined, guest("a", "A", rsvp = "no", opened = true).status)
        assertEquals(GuestStatus.Viewed, guest("a", "A", sent = true, opened = true).status)
        assertEquals(GuestStatus.Pending, guest("a", "A", sent = true).status)
        assertEquals(GuestStatus.Unsent, guest("a", "A").status)
    }

    @Test
    fun searchByFoldedNameOrPhoneDigits() {
        val g = guest("1", "Rəşad Əliyev", phone = "+994501234567")
        assertTrue(searchMatches(g, "resad"))
        assertTrue(searchMatches(g, "ƏLİYEV"))
        assertTrue(searchMatches(g, "050 123"))
        assertFalse(searchMatches(g, "12"))
        assertFalse(searchMatches(g, "Leyla"))
        assertTrue(searchMatches(g, "  "))
    }

    @Test
    fun limitLevels() {
        assertEquals(LimitLevel.Normal, limitLevel(94, 100))
        assertEquals(LimitLevel.Near, limitLevel(95, 100))
        assertEquals(LimitLevel.Full, limitLevel(100, 100))
        assertEquals(LimitLevel.Normal, limitLevel(5, null))
    }

    @Test
    fun onlyChangedColumnsAreSent() {
        val before = NewGuest("Leyla", Salutation.Xanim, false, 1, "+994551112233", Side.Bride, "7")
        assertTrue(guestChanges(before, before).isEmpty())
        assertEquals(setOf("table_no", "invited_count"), guestChanges(before, before.copy(tableNo = "8", invitedCount = 2)).keys)
        assertEquals("blank table becomes null", "null", guestChanges(before, before.copy(tableNo = " ")).getValue("table_no").toString())
    }

    @Test
    fun filtersCountsAndSearch() {
        val vm = GuestListViewModel("e1", true, repo, events, spec)
        val s = vm.state.value
        assertEquals(100, s.limit)
        assertEquals("ru", s.eventLang)
        assertEquals(5, s.count(GuestFilter.All))
        assertEquals(2, s.count(GuestFilter.Groom))
        assertEquals(1, s.count(GuestFilter.Coming))
        assertEquals(1, s.count(GuestFilter.Declined))
        assertEquals("viewed + sent without answer", 2, s.count(GuestFilter.NoAnswer))
        assertEquals(1, s.count(GuestFilter.Unsent))
        assertEquals(3, s.count(GuestFilter.NoTable))
        vm.filter(GuestFilter.Bride)
        assertEquals(listOf("Leyla", "Nərmin"), vm.state.value.visible.map { it.name })
        vm.search("nerm")
        assertEquals(listOf("Nərmin"), vm.state.value.visible.map { it.name })
    }

    @Test
    fun editSavesChangedFieldsAndUpdatesTheRow() {
        val vm = GuestListViewModel("e1", false, repo, events, spec)
        vm.open(vm.state.value.guests.first { it.id == "2" })
        vm.edit { it.copy(table = "9", salutation = Salutation.Xanim) }
        vm.saveEdit()
        assertEquals("update:2", repo.calls.single())
        assertEquals("9", repo.lastUpdate!!.second.tableNo)
        assertEquals("7", repo.lastUpdate!!.first.tableNo)
        assertNull(vm.state.value.editing)
        assertEquals(GuestMessage.Saved, vm.state.value.message)
        assertEquals("9", vm.state.value.guests.first { it.id == "2" }.tableNo)
    }

    @Test
    fun editRejectsBadPhoneAndEmptyName() {
        val vm = GuestListViewModel("e1", true, repo, events, spec)
        vm.open(vm.state.value.guests.first())
        vm.edit { it.copy(phone = "012 345 67 89") }
        vm.saveEdit()
        vm.edit { it.copy(phone = "", name = "  ") }
        vm.saveEdit()
        assertTrue(vm.state.value.editing!!.nameError)
        assertTrue(repo.calls.isEmpty())
    }

    @Test
    fun cohostCannotDeleteOwnerCan() {
        val cohost = GuestListViewModel("e1", false, repo, events, spec)
        cohost.askDelete(listOf("1"))
        assertNull(cohost.state.value.confirmDelete)

        val owner = GuestListViewModel("e1", true, repo, events, spec)
        owner.toggle("1"); owner.toggle("3")
        owner.askDelete(owner.state.value.selected.toList())
        owner.confirmDelete()
        assertEquals("delete:[1, 3]", repo.calls.last())
        assertEquals(3, owner.state.value.guests.size)
        assertFalse(owner.state.value.selecting)
    }

    @Test
    fun bulkTableAndSide() {
        val vm = GuestListViewModel("e1", false, repo, events, spec)
        vm.toggle("4"); vm.toggle("5")
        vm.bulkTable(" 14 ")
        assertEquals("bulk:table_no=14:[4, 5]", repo.calls.last())
        assertEquals("14", vm.state.value.guests.first { it.id == "5" }.tableNo)
        vm.toggle("5")
        vm.bulkSide(Side.Bride)
        assertEquals(Side.Bride, vm.state.value.guests.first { it.id == "5" }.side)
        vm.toggle("1")
        vm.bulkTable("")
        assertEquals("empty means no table", "bulk:table_no=null:[1]", repo.calls.last())
    }

    @Test
    fun loadErrorKeepsCachedRows() {
        val vm = GuestListViewModel("e1", true, repo, events, spec)
        repo.listResult = AuthResult.Failure(AuthError.Network)
        vm.load(refresh = true)
        assertEquals(AuthError.Network, vm.state.value.error)
        assertEquals(5, vm.state.value.guests.size)
    }

    // --- real supabase-kt against canned PostgREST answers ---

    private val requests = mutableListOf<HttpRequestData>()

    private fun supa(status: Int, body: String) = SupabaseGuestListRepository(createSupabaseClient("https://test.supabase.co", "anon-key") {
        httpEngine = MockEngine { req -> requests += req; respond(body, HttpStatusCode.fromValue(status), headersOf(HttpHeaders.ContentType, "application/json")) }
        install(Auth) {
            sessionManager = MemorySessionManager(); codeVerifierCache = MemoryCodeVerifierCache()
            autoLoadFromStorage = false; alwaysAutoRefresh = false; enableLifecycleCallbacks = false
        }
        install(Postgrest)
    })

    private fun HttpRequestData.text() = (body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()

    @Test
    fun listAndLimitRequests() = runTest {
        val rows = """[{"id":"1","code":"K7D2M9QX","salutation":"muellim","name":"Elçin","with_family":true,"invited_count":4,
            "phone_e164":"+994501234567","side":"groom","table_no":"12","lang":null,"sent_at":"2027-06-01T10:00:00+00:00",
            "opened_at":null,"rsvp_status":"pending","rsvp_count":0,"event_id":"e1","added_by":null}]"""
        val g = (supa(200, rows).list("e1") as AuthResult.Ok).value.single()
        assertEquals(GuestStatus.Pending, g.status)
        assertEquals("eq.e1", requests.single().url.parameters["event_id"])
        assertTrue(requests.single().url.parameters["order"]!!.startsWith("name.asc"))
        requests.clear()
        assertEquals(AuthResult.Ok(300), supa(200, "300").limit("e1"))
        assertTrue(requests.single().url.encodedPath.endsWith("/rpc/event_guest_limit"))
        assertEquals("""{"p_event_id":"e1"}""", requests.single().text())
    }

    @Test
    fun bulkAndDeleteRequests() = runTest {
        assertEquals(AuthResult.Ok(Unit), supa(200, """[{"id":"1"},{"id":"2"}]""").bulkUpdate(listOf("1", "2"), "table_no", "14"))
        assertEquals(HttpMethod.Patch, requests.single().method)
        assertEquals("in.(1,2)", requests.single().url.parameters["id"])
        assertEquals("""{"table_no":"14"}""", requests.single().text())
        requests.clear()
        assertEquals("co-host: RLS hides the rows", AuthResult.Failure(AuthError.Forbidden), supa(200, "[]").delete(listOf("1")))
        assertEquals(HttpMethod.Delete, requests.single().method)
    }
}
