package az.devet.app.di

import az.devet.app.data.account.AccountRepository
import az.devet.app.data.account.Profile
import az.devet.app.data.auth.AuthRepository
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.SessionState
import az.devet.app.data.events.EventDraft
import az.devet.app.data.events.EventRepository
import az.devet.app.data.events.EventRules
import az.devet.app.data.events.EventSummary
import az.devet.app.data.events.EventType
import az.devet.app.data.events.MemberRole
import az.devet.app.data.guests.AddResult
import az.devet.app.data.guests.GuestPhone
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.GuestListRepository
import az.devet.app.data.guests.GuestRepository
import az.devet.app.data.guests.Salutation
import az.devet.app.data.guests.Side
import az.devet.app.data.guests.NewGuest
import kotlinx.coroutines.flow.MutableStateFlow
import org.koin.core.module.Module
import org.koin.dsl.module
import java.time.Instant
import java.time.LocalDateTime
import java.util.UUID

/**
 * Debug-only demo backend (DEVET_DEMO=true in local.properties): signed in, events kept in memory.
 * Lets screens be tried on an emulator before a Supabase project exists. Never part of release builds.
 */
fun demoModule(): Module = module {
    single<AuthRepository> { DemoAuth() }
    single<AccountRepository> { DemoAccount() }
    single<EventRepository> { DemoEvents() }
    single { DemoGuests() }
    single<GuestRepository> { get<DemoGuests>() }
    single<GuestListRepository> { get<DemoGuests>() }
}

/** In-memory guests with the free limit (100), so the limit sheet can be tried too; one demo event has guests. */
private class DemoGuests : GuestRepository, GuestListRepository {
    private val byEvent = mutableMapOf<String, MutableList<Guest>>()
    private var nextId = 0

    init {
        val sample = listOf(
            NewGuest("Elçin", Salutation.Muellim, true, 4, "+994501234567", Side.Groom, "12"),
            NewGuest("Leyla", Salutation.Xanim, false, 1, "+994551112233", Side.Bride, "7"),
            NewGuest("Rəşad", Salutation.Bey, false, 2, "+994701234567", Side.Groom, null),
            NewGuest("Nərmin", Salutation.Xanim, true, 3, null, Side.Bride, "7"),
            NewGuest("Kamran", Salutation.None, false, 1, "+994771234567", Side.None, "3", "ru"),
        )
        val states = listOf("yes" to 4, "pending" to 0, "no" to 0, "pending" to 0, "pending" to 0)
        byEvent["demo-1"] = sample.mapIndexed { i, g ->
            guest(g).copy(
                rsvpStatus = states[i].first, rsvpCount = states[i].second,
                sentAt = if (i != 4) "2027-06-01T10:00:00Z" else null, openedAt = if (i == 3) "2027-06-02T10:00:00Z" else null,
            )
        }.toMutableList()
    }

    private fun guest(g: NewGuest) = Guest(
        "g${nextId++}", "CODE$nextId", g.salutation, g.name, g.withFamily, g.invitedCount, g.phoneE164, g.side, g.tableNo, g.lang,
        null, null, "pending", 0,
    )

    override suspend fun phones(eventId: String) =
        AuthResult.Ok(byEvent[eventId].orEmpty().mapNotNull { g -> g.phoneE164?.let { GuestPhone(g.name, it) } })
    override suspend fun count(eventId: String) = AuthResult.Ok(byEvent[eventId]?.size ?: 0)
    override suspend fun add(eventId: String, guests: List<NewGuest>): AddResult {
        val list = byEvent.getOrPut(eventId) { mutableListOf() }
        if (list.size + guests.size > 100) return AddResult.LimitExceeded(100)
        list += guests.map(::guest)
        return AddResult.Added(guests.size)
    }

    override suspend fun list(eventId: String) = AuthResult.Ok(byEvent[eventId].orEmpty().sortedBy { it.name })
    override suspend fun limit(eventId: String) = AuthResult.Ok<Int?>(100)
    override suspend fun update(id: String, before: NewGuest, after: NewGuest): AuthResult<Unit> {
        byEvent.values.forEach { list ->
            list.replaceAll { g ->
                if (g.id == id) g.copy(
                    salutation = after.salutation, name = after.name, withFamily = after.withFamily, invitedCount = after.invitedCount,
                    phoneE164 = after.phoneE164, side = after.side, tableNo = after.tableNo, lang = after.lang,
                ) else g
            }
        }
        return AuthResult.Ok(Unit)
    }
    override suspend fun bulkUpdate(ids: List<String>, column: String, value: String?): AuthResult<Unit> {
        byEvent.values.forEach { list -> list.replaceAll { g -> if (g.id !in ids) g else if (column == "side") g.copy(side = Side.of(value)) else g.copy(tableNo = value) } }
        return AuthResult.Ok(Unit)
    }
    override suspend fun delete(ids: List<String>): AuthResult<Unit> {
        byEvent.values.forEach { list -> list.removeAll { it.id in ids } }
        return AuthResult.Ok(Unit)
    }
}

private class DemoAuth : AuthRepository {
    override val session = MutableStateFlow(SessionState.SignedIn)
    override val currentEmail = "demo@devet.az"
    override suspend fun signIn(email: String, password: String) = AuthResult.Ok(Unit).also { session.value = SessionState.SignedIn }
    override suspend fun signUp(name: String, email: String, password: String) = AuthResult.Ok(true)
    override suspend fun resendConfirmation(email: String) = AuthResult.Ok(Unit)
    override suspend fun sendPasswordReset(email: String) = AuthResult.Ok(Unit)
    override suspend fun exchangeCode(code: String) = AuthResult.Ok(Unit)
    override suspend fun updatePassword(password: String) = AuthResult.Ok(Unit)
    override suspend fun signOut() { session.value = SessionState.SignedOut }
}

private class DemoAccount : AccountRepository {
    override suspend fun profile() = AuthResult.Ok(Profile("demo", "demo@devet.az", "Aysel", "az"))
    override suspend fun updateName(name: String) = AuthResult.Ok(Unit)
    override suspend fun updateLanguage(lang: String) = AuthResult.Ok(Unit)
    override suspend fun deleteAccount() = AuthResult.Ok(Unit)
}

private class DemoEvents : EventRepository {
    private data class Item(val draft: EventDraft, val role: MemberRole, val guests: Int, val coming: Int, val noAnswer: Int)

    private fun at(y: Int, m: Int, d: Int, h: Int) = LocalDateTime.of(y, m, d, h, 0).atZone(EventRules.ZONE).toInstant()
    private val items = linkedMapOf(
        "demo-1" to Item(EventDraft(EventType.Wedding, "Aysel və Ramin", "Məmmədovlar və Əliyevlər ailələri", at(2027, 7, 12, 18), "Ağ Saray şadlıq evi",
            "Bakı, Nərimanov r-nu", "https://maps.google.com/?q=40.4093,49.8671", "az", false), MemberRole.Owner, 212, 121, 59),
        "demo-2" to Item(EventDraft(EventType.Birthday, "Nərminin ad günü", "", at(2027, 8, 3, 17), "Mərcan restoranı", "", "", "ru", true),
            MemberRole.Cohost, 40, 22, 14),
        "demo-3" to Item(EventDraft(EventType.Engagement, "Leyla və Tural", "", Instant.now().minusSeconds(30 * 86400), "Gülüstan sarayı", "", "", "az", false),
            MemberRole.Owner, 80, 64, 0),
    )

    override suspend fun list() = AuthResult.Ok(items.map { (id, it) ->
        EventSummary(id, it.draft.type!!, it.draft.titleNames, it.draft.startsAt!!, it.draft.venueName, null, it.role, it.guests, it.coming, it.noAnswer)
    })
    override suspend fun get(id: String) = AuthResult.Ok(items.getValue(id).draft)
    override suspend fun create(draft: EventDraft): AuthResult<String> {
        val id = UUID.randomUUID().toString()
        items[id] = Item(draft, MemberRole.Owner, 0, 0, 0)
        return AuthResult.Ok(id)
    }
    override suspend fun update(id: String, before: EventDraft, after: EventDraft): AuthResult<Unit> {
        items[id] = items.getValue(id).copy(draft = after)
        return AuthResult.Ok(Unit)
    }
    override suspend fun delete(id: String): AuthResult<Unit> {
        if (items[id]?.role == MemberRole.Cohost) return AuthResult.Failure(az.devet.app.data.auth.AuthError.Forbidden)
        items.remove(id)
        return AuthResult.Ok(Unit)
    }
}
