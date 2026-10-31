package az.devet.app.auth

import az.devet.app.data.AppLanguage
import az.devet.app.data.account.AccountRepository
import az.devet.app.data.account.Profile
import az.devet.app.data.auth.AuthRepository
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.auth.SessionState
import az.devet.app.data.network.Connectivity
import kotlinx.coroutines.flow.MutableStateFlow

class FakeAuth : AuthRepository {
    override val session = MutableStateFlow(SessionState.SignedOut)
    override var currentEmail: String? = "aysel@example.com"
    val calls = mutableListOf<String>()

    var signInResult: AuthResult<Unit> = AuthResult.Ok(Unit)
    var signUpResult: AuthResult<Boolean> = AuthResult.Ok(true)
    var resetResult: AuthResult<Unit> = AuthResult.Ok(Unit)
    var exchangeResult: AuthResult<Unit> = AuthResult.Ok(Unit)
    var updateResult: AuthResult<Unit> = AuthResult.Ok(Unit)

    override suspend fun signIn(email: String, password: String) = signInResult.also { calls += "signIn:$email" }
    override suspend fun signUp(name: String, email: String, password: String) = signUpResult.also { calls += "signUp:$name:$email" }
    override suspend fun resendConfirmation(email: String): AuthResult<Unit> = AuthResult.Ok(Unit).also { calls += "resend:$email" }
    override suspend fun sendPasswordReset(email: String) = resetResult.also { calls += "reset:$email" }
    override suspend fun exchangeCode(code: String) = exchangeResult.also { calls += "exchange:$code" }
    override suspend fun updatePassword(password: String) = updateResult.also { calls += "update" }
    override suspend fun signOut() {
        calls += "signOut"
        session.value = SessionState.SignedOut
    }
}

class FakeAccount : AccountRepository {
    val calls = mutableListOf<String>()
    var profileResult: AuthResult<Profile> = AuthResult.Ok(Profile("u1", "aysel@example.com", "Aysel", "az"))
    var deleteResult: AuthResult<Unit> = AuthResult.Ok(Unit)

    override suspend fun profile() = profileResult
    override suspend fun updateName(name: String): AuthResult<Unit> = AuthResult.Ok(Unit).also { calls += "name:$name" }
    override suspend fun updateLanguage(lang: String): AuthResult<Unit> = AuthResult.Ok(Unit).also { calls += "lang:$lang" }
    override suspend fun deleteAccount() = deleteResult.also { calls += "delete" }
}

class FakeConnectivity(online: Boolean = true) : Connectivity {
    override val isOnline = MutableStateFlow(online)
}

class FakeLanguage(override var selected: String? = null, private val system: String = "ru") : AppLanguage {
    override val effective get() = selected ?: system
    override fun select(lang: String?) { selected = lang }
}
