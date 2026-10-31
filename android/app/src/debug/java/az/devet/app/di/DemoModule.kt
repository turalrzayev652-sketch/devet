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
