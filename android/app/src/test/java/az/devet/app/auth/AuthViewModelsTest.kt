package az.devet.app.auth

import az.devet.app.data.account.Profile
import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult
import az.devet.app.ui.AppMessage
import az.devet.app.ui.AppViewModel
import az.devet.app.ui.auth.NewPasswordViewModel
import az.devet.app.ui.auth.RegisterViewModel
import az.devet.app.ui.auth.ResetPasswordViewModel
import az.devet.app.ui.auth.SignInViewModel
import az.devet.app.ui.settings.SettingsViewModel
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

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelsTest {
    private val auth = FakeAuth()

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test
    fun wrongPasswordShowsCredentialsError() {
        auth.signInResult = AuthResult.Failure(AuthError.InvalidCredentials)
        val vm = SignInViewModel(auth, FakeConnectivity())
        vm.onEmail("aysel@example.com"); vm.onPassword("wrong")
        vm.submit()
        assertEquals(AuthError.InvalidCredentials, vm.state.value.error)
        assertFalse(vm.state.value.loading)
        vm.onPassword("wrong2")
        assertNull("typing clears the error", vm.state.value.error)
    }

    @Test
    fun unconfirmedEmailOpensConfirmation() {
        auth.signInResult = AuthResult.Failure(AuthError.EmailNotConfirmed)
        val vm = SignInViewModel(auth, FakeConnectivity())
        vm.onEmail(" aysel@example.com "); vm.onPassword("secret1")
        vm.submit()
        assertEquals("aysel@example.com", vm.state.value.unconfirmedEmail)
        assertNull(vm.state.value.error)
    }

    @Test
    fun invalidFormDoesNotCallBackend() {
        val vm = SignInViewModel(auth, FakeConnectivity())
        vm.onEmail("not-an-email"); vm.onPassword("x")
        vm.submit()
        assertTrue(auth.calls.isEmpty())
    }

    @Test
    fun registerFlow() {
        val vm = RegisterViewModel(auth, FakeConnectivity())
        vm.onName("Aysel"); vm.onEmail("aysel@example.com"); vm.onPassword("secret1"); vm.onRepeat("secret2")
        assertTrue(vm.state.value.passwordMismatch)
        vm.onRepeat("secret1")
        assertFalse(vm.state.value.passwordMismatch)
        assertTrue("only the checkbox is missing", vm.state.value.termsMissing)
        assertFalse(vm.state.value.canSubmit)
        vm.onTerms(true)
        vm.submit()
        assertEquals(listOf("signUp:Aysel:aysel@example.com"), auth.calls)
        assertEquals("aysel@example.com", vm.state.value.confirmationSentTo)
    }

    @Test
    fun registerExistingEmail() {
        auth.signUpResult = AuthResult.Failure(AuthError.UserAlreadyExists)
        val vm = RegisterViewModel(auth, FakeConnectivity())
        vm.onName("Aysel"); vm.onEmail("aysel@example.com"); vm.onPassword("secret1"); vm.onRepeat("secret1"); vm.onTerms(true)
        vm.submit()
        assertEquals(AuthError.UserAlreadyExists, vm.state.value.error)
        assertNull(vm.state.value.confirmationSentTo)
    }

    @Test
    fun resetNeverRevealsAccounts() {
        auth.resetResult = AuthResult.Failure(AuthError.Unknown)
        val vm = ResetPasswordViewModel(auth, FakeConnectivity())
        vm.onEmail("nobody@example.com")
        vm.submit()
        assertTrue(vm.state.value.sent)

        auth.resetResult = AuthResult.Failure(AuthError.Network)
        val offline = ResetPasswordViewModel(auth, FakeConnectivity())
        offline.onEmail("aysel@example.com")
        offline.submit()
        assertFalse(offline.state.value.sent)
        assertEquals(AuthError.Network, offline.state.value.error)
    }

    @Test
    fun newPasswordNeedsMatchingSixChars() {
        val vm = NewPasswordViewModel(auth)
        vm.onPassword("12345"); vm.onRepeat("12345")
        assertFalse(vm.state.value.canSubmit)
        vm.onPassword("123456"); vm.onRepeat("123456")
        vm.submit()
        assertTrue(vm.state.value.done)
    }

    @Test
    fun recoveryLinkOpensNewPassword() {
        val app = AppViewModel(auth)
        app.handleLink("az.devet.app://auth/reset-password?code=k1")
        assertEquals(listOf("exchange:k1"), auth.calls)
        assertTrue(app.recovery.value)
        app.passwordUpdated()
        assertFalse(app.recovery.value)
        assertEquals(AppMessage.PasswordUpdated, app.message.value)
    }

    @Test
    fun badLinksShowAMessage() {
        val app = AppViewModel(auth)
        app.handleLink("az.devet.app://auth/callback#error_code=otp_expired")
        assertEquals(AppMessage.LinkInvalid, app.message.value)
        assertTrue(auth.calls.isEmpty())

        app.messageShown()
        auth.exchangeResult = AuthResult.Failure(AuthError.LinkInvalid)
        app.handleLink("az.devet.app://auth/reset-password?code=used")
        assertFalse("failed exchange leaves recovery", app.recovery.value)
        assertEquals(AppMessage.LinkInvalid, app.message.value)

        app.messageShown()
        app.handleLink("https://example.com/")
        assertNull("foreign links are ignored", app.message.value)
    }

    @Test
    fun settingsDeleteNeedsTypedEmail() {
        val account = FakeAccount()
        val vm = SettingsViewModel(account, auth, FakeLanguage())
        assertEquals("Aysel", vm.state.value.name)
        vm.openDelete()
        vm.onDeleteConfirm("other@example.com")
        assertFalse(vm.state.value.canDelete)
        vm.onDeleteConfirm(" AYSEL@example.com ")
        assertTrue(vm.state.value.canDelete)
        vm.deleteAccount()
        assertEquals(listOf("delete"), account.calls)
        assertTrue("signed out after deletion", "signOut" in auth.calls)
    }

    @Test
    fun settingsDeleteFailureKeepsSession() {
        val account = FakeAccount().apply { deleteResult = AuthResult.Failure(AuthError.Unknown) }
        val vm = SettingsViewModel(account, auth, FakeLanguage())
        vm.openDelete(); vm.onDeleteConfirm("aysel@example.com")
        vm.deleteAccount()
        assertTrue(vm.state.value.deleteFailed)
        assertFalse("signOut" in auth.calls)
    }

    @Test
    fun settingsLanguageAndName() {
        val account = FakeAccount().apply { profileResult = AuthResult.Ok(Profile("u1", "aysel@example.com", "Aysel", "az")) }
        val lang = FakeLanguage(selected = null, system = "ru")
        val vm = SettingsViewModel(account, auth, lang)
        vm.selectLanguage("tr")
        assertEquals("tr", lang.selected)
        vm.selectLanguage(null)
        assertNull(lang.selected)
        assertEquals("system choice stores the language in use", listOf("lang:tr", "lang:ru"), account.calls)

        assertFalse("unchanged name", vm.state.value.canSaveName)
        vm.onName(" Aysel Məmmədova ")
        vm.saveName()
        assertEquals("name:Aysel Məmmədova", account.calls.last())
        assertTrue(vm.state.value.saved)
    }
}
