package az.devet.app.ui.send

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventRepository
import az.devet.app.data.events.EventType
import az.devet.app.data.guests.DisplayNames
import az.devet.app.data.guests.FakeGuestList
import az.devet.app.data.guests.FakeStorageRepository
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class PreviewListViewModelTest {
    private lateinit var repo: FakeGuestList
    private lateinit var events: FakeEventRepo
    private lateinit var storage: FakeStorageRepository
    private lateinit var displayNames: DisplayNames
    private lateinit var viewModel: PreviewListViewModel

    @Before
    fun setUp() {
        repo = FakeGuestList()
        events = FakeEventRepo()
        storage = FakeStorageRepository()
        displayNames = DisplayNames(mapOf(
            Salutation.Muellim to ("müəllim", "учитель", "teacher", "öğretmen"),
            Salutation.Xanim to ("xanım", "госпожа", "madam", "hanım"),
            Salutation.Bey to ("bəy", "господин", "sir", "bey"),
            Salutation.None to ("", "", "", "")
        ))
    }

    @Test
    fun loadsAndGeneratePreviews() = runTest {
        viewModel = PreviewListViewModel("event-1", repo, events, storage, displayNames)
        advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(5, state.guests.size)  // 5 demo guests
        assertTrue(state.allReady)
        assertEquals(5, storage.uploads.size)  // All 5 previews uploaded
    }

    @Test
    fun countsWarnings() = runTest {
        // Guest without phone
        repo.guests = listOf(
            Guest("1", "K1", Salutation.None, "Alice", false, 1, "+994501234567", Side.None, null, null, null, null, "pending", 0),
            Guest("2", "K2", Salutation.None, "", false, 1, "+994551234567", Side.None, null, null, null, null, "pending", 0),  // empty name
            Guest("3", "K3", Salutation.None, "Charlie", false, 1, null, Side.None, null, null, null, null, "pending", 0),  // no phone
        )

        viewModel = PreviewListViewModel("event-1", repo, events, storage, displayNames)
        advanceUntilIdle()

        val state = viewModel.state.value
        val warnings = state.warnings.associate { it.type to it.count }
        assertEquals(1, warnings["empty_name"])
        assertEquals(1, warnings["no_phone"])
    }

    @Test
    fun showsUploadProgress() = runTest {
        viewModel = PreviewListViewModel("event-1", repo, events, storage, displayNames)
        // Don't wait - we'll check the intermediate state
        val state = viewModel.state.value
        // At this point, either it's loading or done
        assertTrue(state.loading || state.allReady)
    }

    @Test
    fun handlesUploadFailure() = runTest {
        storage.uploadFailureAfterCount = 2  // Fail on 3rd upload
        viewModel = PreviewListViewModel("event-1", repo, events, storage, displayNames)
        advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(AuthError.Network, state.uploadError)
        assertTrue(state.uploadProgress.contains("xəta"))
    }

    @Test
    fun filtersOutGuestsWithoutPhones() = runTest {
        repo.guests = listOf(
            Guest("1", "K1", Salutation.None, "Alice", false, 1, "+994501234567", Side.None, null, null, null, null, "pending", 0),
            Guest("2", "K2", Salutation.None, "Bob", false, 1, null, Side.None, null, null, null, null, "pending", 0),
        )

        viewModel = PreviewListViewModel("event-1", repo, events, storage, displayNames)
        advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(1, state.guests.size)  // Only Alice with phone
        assertEquals(1, storage.uploads.size)
    }

    private class FakeEventRepo : EventRepository {
        override val list = MutableStateFlow(emptyList<Any>())
        override suspend fun list() = AuthResult.Ok(emptyList())
        override suspend fun get(id: String) = AuthResult.Ok(
            EventDraft(EventType.Wedding, "Test Event", "", Instant.now(), "Test Venue", "", "", "az", false, null, null)
        )
        override suspend fun create(draft: EventDraft) = AuthResult.Ok("event-1")
        override suspend fun update(id: String, before: EventDraft, after: EventDraft) = AuthResult.Ok(Unit)
        override suspend fun delete(id: String) = AuthResult.Ok(Unit)
    }
}
