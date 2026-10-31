package az.devet.app.events

import az.devet.app.auth.FakeLanguage
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.ArchiveStore
import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventRepository
import az.devet.app.data.events.EventSummary
import az.devet.app.data.events.EventType
import az.devet.app.data.events.MemberRole
import az.devet.app.ui.events.CreateEventViewModel
import az.devet.app.ui.events.EditEventViewModel
import az.devet.app.ui.events.EventsMessage
import az.devet.app.ui.events.EventsViewModel
import az.devet.app.ui.events.MapStatus
import az.devet.app.ui.events.mapStatus
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
import java.time.Instant

class FakeEvents : EventRepository {
    val calls = mutableListOf<String>()
    var listResult: AuthResult<List<EventSummary>> = AuthResult.Ok(emptyList())
    var getResult: AuthResult<EventDraft> = AuthResult.Ok(EventDraft())
    var createResult: AuthResult<String> = AuthResult.Ok("new-id")
    var updateResult: AuthResult<Unit> = AuthResult.Ok(Unit)
    var deleteResult: AuthResult<Unit> = AuthResult.Ok(Unit)
    var lastCreated: EventDraft? = null
    var lastUpdate: Pair<EventDraft, EventDraft>? = null

    override suspend fun list() = listResult.also { calls += "list" }
    override suspend fun get(id: String) = getResult.also { calls += "get:$id" }
    override suspend fun create(draft: EventDraft) = createResult.also { calls += "create"; lastCreated = draft }
    override suspend fun update(id: String, before: EventDraft, after: EventDraft) = updateResult.also { calls += "update:$id"; lastUpdate = before to after }
    override suspend fun delete(id: String) = deleteResult.also { calls += "delete:$id" }
}

class MemoryArchive : ArchiveStore {
    private val ids = mutableSetOf<String>()
    override fun archived() = ids.toSet()
    override fun setArchived(id: String, archived: Boolean) { if (archived) ids += id else ids -= id }
}

@OptIn(ExperimentalCoroutinesApi::class)
class EventsViewModelsTest {
    private val now = Instant.parse("2027-01-10T10:00:00Z")
    private val repo = FakeEvents()

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    private fun event(id: String, daysFromNow: Long, role: MemberRole = MemberRole.Owner) = EventSummary(
        id, EventType.Wedding, "Event $id", now.plusSeconds(daysFromNow * 86400), "Hall", null, role, 10, 4, 3,
    )

    @Test
    fun listSplitsActiveAndArchive() {
        repo.listResult = AuthResult.Ok(listOf(event("old", -30), event("far", 60), event("soon", 5), event("recent", -2)))
        val vm = EventsViewModel(repo, MemoryArchive()) { now }
        val s = vm.state.value
        assertEquals("upcoming soonest first, then the last 7 days", listOf("soon", "far", "recent"), s.active.map { it.id })
        assertEquals(listOf("old"), s.archived.map { it.id })
        assertFalse(s.loading)
    }

    @Test
    fun manualArchiveIsLocalAndReversible() {
        val archive = MemoryArchive()
        repo.listResult = AuthResult.Ok(listOf(event("a", 5), event("old", -30)))
        val vm = EventsViewModel(repo, archive) { now }
        val a = vm.state.value.active.single()
        vm.setArchived(a, true)
        assertTrue(vm.state.value.active.isEmpty())
        assertTrue(vm.state.value.canUnarchive(a))
        assertFalse("date-based archive cannot be undone", vm.state.value.canUnarchive(vm.state.value.archived.first { it.id == "old" }))
        vm.setArchived(a, false)
        assertEquals(listOf("a"), vm.state.value.active.map { it.id })
        assertTrue("no server call for archiving", repo.calls.none { it.startsWith("update") })
    }

    @Test
    fun deleteRemovesTheCard() {
        repo.listResult = AuthResult.Ok(listOf(event("a", 5)))
        val vm = EventsViewModel(repo, MemoryArchive()) { now }
        vm.askDelete(vm.state.value.active.single())
        vm.confirmDelete()
        assertEquals("delete:a", repo.calls.last())
        assertTrue(vm.state.value.events.isEmpty())
        assertEquals(EventsMessage.Deleted, vm.state.value.message)
        assertNull(vm.state.value.deleteTarget)
    }

    @Test
    fun cohostDeleteRefusedByServerKeepsTheCard() {
        repo.listResult = AuthResult.Ok(listOf(event("a", 5, MemberRole.Cohost)))
        repo.deleteResult = AuthResult.Failure(AuthError.Forbidden)
        val vm = EventsViewModel(repo, MemoryArchive()) { now }
        vm.askDelete(vm.state.value.active.single())
        vm.confirmDelete()
        assertEquals(1, vm.state.value.events.size)
        assertEquals(AuthError.Forbidden, vm.state.value.actionError)
    }

    @Test
    fun loadErrorKeepsCachedCards() {
        repo.listResult = AuthResult.Ok(listOf(event("a", 5)))
        val vm = EventsViewModel(repo, MemoryArchive()) { now }
        repo.listResult = AuthResult.Failure(AuthError.Network)
        vm.load(refresh = true)
        assertEquals(AuthError.Network, vm.state.value.error)
        assertEquals(1, vm.state.value.events.size)
    }

    @Test
    fun wizardWalksSixStepsAndCreates() {
        val vm = CreateEventViewModel(repo, FakeLanguage(system = "ru")) { now }
        assertEquals("default language = app language", "ru", vm.state.value.draft.defaultLang)
        vm.next()
        assertEquals("type missing — stays on step 1", 1, vm.state.value.step)
        vm.edit { it.copy(type = EventType.Henna) }; vm.next()
        vm.edit { it.copy(titleNames = "Aysel") }; vm.next()
        vm.edit { it.copy(startsAt = now.minusSeconds(3600)) }; vm.next()
        assertEquals("past date blocked", 3, vm.state.value.step)
        vm.edit { it.copy(startsAt = now.plusSeconds(86400)) }; vm.next()
        vm.edit { it.copy(venueName = "Hall", mapsUrl = "javascript:alert(1)") }; vm.next()
        assertEquals("invalid link blocked", 4, vm.state.value.step)
        vm.edit { it.copy(mapsUrl = "") }; vm.next()
        vm.next()
        assertEquals(6, vm.state.value.step)
        assertFalse("tablemates off by default", vm.state.value.draft.showTablemates)
        vm.back()
        assertEquals(5, vm.state.value.step)
        vm.next(); vm.next()
        assertEquals("new-id", vm.state.value.createdId)
        assertEquals(EventType.Henna, repo.lastCreated?.type)
    }

    @Test
    fun failedCreateKeepsTheForm() {
        repo.createResult = AuthResult.Failure(AuthError.Network)
        val vm = CreateEventViewModel(repo, FakeLanguage()) { now }
        vm.edit { it.copy(type = EventType.Wedding, titleNames = "A", startsAt = now.plusSeconds(86400), venueName = "H") }
        repeat(6) { vm.next() }
        assertEquals(AuthError.Network, vm.state.value.error)
        assertNull(vm.state.value.createdId)
        assertEquals("A", vm.state.value.draft.titleNames)
        assertEquals(6, vm.state.value.step)
    }

    @Test
    fun editOfPastEventAllowsOtherChangesButNotAPastDate() {
        val past = EventDraft(EventType.Wedding, "A", "", now.minusSeconds(86400), "Hall", "", "", "az", false)
        repo.getResult = AuthResult.Ok(past)
        val vm = EditEventViewModel(repo, "e1") { now }
        assertFalse("nothing changed", vm.state.value.canSave)
        vm.edit { it.copy(venueName = "New hall") }
        assertTrue(vm.state.value.canSave)
        vm.edit { it.copy(startsAt = now.minusSeconds(7200)) }
        assertFalse("another past date", vm.state.value.canSave)
        vm.edit { it.copy(startsAt = now.plusSeconds(7200)) }
        vm.save()
        assertEquals("update:e1", repo.calls.last())
        assertEquals(past, repo.lastUpdate?.first)
        assertTrue(vm.state.value.saved)
    }

    @Test
    fun mapStatusTexts() {
        assertEquals(MapStatus.None, mapStatus(""))
        assertEquals(MapStatus.CoordsFound, mapStatus("https://maps.google.com/?q=40.3536,49.8364"))
        assertEquals(MapStatus.NoCoords, mapStatus("https://maps.app.goo.gl/AbCdEf123"))
        assertEquals(MapStatus.Invalid, mapStatus("ftp://maps.google.com/?q=1,2"))
    }
}
