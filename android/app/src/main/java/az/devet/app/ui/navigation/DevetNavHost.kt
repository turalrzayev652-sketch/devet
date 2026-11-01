package az.devet.app.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import az.devet.app.R
import az.devet.app.data.AppLanguage
import az.devet.app.data.SupabaseConfig
import az.devet.app.data.auth.SessionState
import az.devet.app.ui.AppMessage
import az.devet.app.ui.AppViewModel
import az.devet.app.ui.auth.ConfirmEmailScreen
import az.devet.app.ui.auth.NewPasswordScreen
import az.devet.app.ui.auth.RegisterScreen
import az.devet.app.ui.auth.ResetPasswordScreen
import az.devet.app.ui.auth.ResetSentScreen
import az.devet.app.ui.auth.SignInScreen
import az.devet.app.ui.events.ComingSoonScreen
import az.devet.app.ui.guests.AddGuestScreen
import az.devet.app.ui.guests.EventScreen
import az.devet.app.ui.events.CreateEventScreen
import az.devet.app.ui.events.EditEventScreen
import az.devet.app.data.events.EventDraft
import az.devet.app.ui.events.EventsScreen
import az.devet.app.ui.settings.SettingsScreen
import az.devet.app.ui.theme.DevetTheme
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.serialization.Serializable
import org.koin.compose.koinInject

/** Type-safe routes. Screens from spec/screens.md are added here module by module. */
sealed interface Route {
    @Serializable data object Splash : Route
    @Serializable data object SignIn : Route
    @Serializable data object Register : Route
    @Serializable data class ConfirmEmail(val email: String) : Route
    @Serializable data object ResetPassword : Route
    @Serializable data object ResetSent : Route
    @Serializable data object NewPassword : Route
    @Serializable data object Events : Route
    @Serializable data object Settings : Route
    @Serializable data object CreateEvent : Route
    @Serializable data class EditEvent(val id: String) : Route
    /** Inside an event: guests [6] (T45/T46). */
    @Serializable data class EventHome(val id: String, val title: String, val owner: Boolean) : Route
    @Serializable data class Templates(val eventId: String) : Route
    @Serializable data class AddGuests(val eventId: String, val tab: Int) : Route
    /** Purchase [12] (T4D). */
    @Serializable data object Purchase : Route
    @Serializable data object JoinByCode : Route
}

/** Root screen for the session: sign-in flow when signed out, the app when signed in (screens.md §1). */
internal fun rootFor(session: SessionState, recovery: Boolean): Route = when {
    session == SessionState.Loading -> Route.Splash
    recovery && session == SessionState.SignedIn -> Route.NewPassword
    session == SessionState.SignedIn -> Route.Events
    else -> Route.SignIn
}

@Composable
fun DevetNavHost(app: AppViewModel) {
    val nav = rememberNavController()
    val session by app.session.collectAsStateWithLifecycle()
    val recovery by app.recovery.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val context = LocalContext.current
    val links = legalLinks(koinInject(), koinInject())

    val root = rootFor(session, recovery)
    LaunchedEffect(root) { nav.resetTo(root) }
    // Collected (not keyed on the value): clearing the message must not cancel the snackbar being shown.
    LaunchedEffect(Unit) {
        app.message.filterNotNull().collect { m ->
            val text = when (m) {
                AppMessage.LinkInvalid -> R.string.auth_error_link_invalid
                AppMessage.Network -> R.string.common_error_network
                AppMessage.PasswordUpdated -> R.string.auth_new_password_done
            }
            app.messageShown()
            snackbar.showSnackbar(context.getString(text))
        }
    }

    Box(Modifier.fillMaxSize().background(DevetTheme.colors.bgCanvas)) {
        NavHost(navController = nav, startDestination = Route.Splash) {
            composable<Route.Splash> { Box(Modifier.fillMaxSize().background(DevetTheme.colors.bgCanvas)) }
            composable<Route.SignIn> {
                SignInScreen(
                    onRegister = { nav.navigate(Route.Register) },
                    onForgot = { nav.navigate(Route.ResetPassword) },
                    onUnconfirmed = { nav.navigate(Route.ConfirmEmail(it)) },
                )
            }
            composable<Route.Register> {
                RegisterScreen(
                    termsUrl = links.terms, privacyUrl = links.privacy,
                    onBack = { nav.popBackStack() },
                    onConfirmationSent = { email -> nav.navigate(Route.ConfirmEmail(email)) { popUpTo<Route.SignIn>() } },
                )
            }
            composable<Route.ConfirmEmail> { ConfirmEmailScreen(it.toRoute<Route.ConfirmEmail>().email, onBack = { nav.popBackStack() }) }
            composable<Route.ResetPassword> {
                ResetPasswordScreen(onBack = { nav.popBackStack() }, onSent = { nav.navigate(Route.ResetSent) { popUpTo<Route.SignIn>() } })
            }
            composable<Route.ResetSent> { ResetSentScreen(onBackToLogin = { nav.popBackStack() }) }
            composable<Route.NewPassword> { NewPasswordScreen(onDone = app::passwordUpdated) }
            composable<Route.Events> { entry ->
                // Bumped by create/edit/delete elsewhere so the list reloads when it comes back.
                val reload by entry.savedStateHandle.getStateFlow(RELOAD_KEY, 0).collectAsStateWithLifecycle()
                EventsScreen(
                    onSettings = { nav.navigate(Route.Settings) },
                    onOpen = { nav.navigate(Route.EventHome(it.id, it.titleNames, it.role == az.devet.app.data.events.MemberRole.Owner)) },
                    onCreate = { nav.navigate(Route.CreateEvent) },
                    onEdit = { nav.navigate(Route.EditEvent(it.id)) },
                    onJoin = { nav.navigate(Route.JoinByCode) },
                    reloadKey = reload,
                )
            }
            composable<Route.CreateEvent> {
                CreateEventScreen(
                    onClose = { nav.popBackStack() },
                    onCreated = { nav.markEventsChanged() },
                    onChooseTemplate = { id -> nav.navigate(Route.Templates(id)) { popUpTo<Route.Events>() } },
                )
            }
            composable<Route.EditEvent> {
                EditEventScreen(it.toRoute<Route.EditEvent>().id, onBack = { nav.popBackStack() }, onSaved = {
                    nav.markEventsChanged()
                    nav.popBackStack()
                })
            }
            composable<Route.EventHome> { entry ->
                val r = entry.toRoute<Route.EventHome>()
                val reload by entry.savedStateHandle.getStateFlow(GUESTS_KEY, 0).collectAsStateWithLifecycle()
                // Load event data for SendFlowScreen
                val eventVm: az.devet.app.ui.events.EditEventViewModel = koinViewModel { parametersOf(r.id) }
                val eventDraft by eventVm.draft.collectAsStateWithLifecycle()
                EventScreen(
                    r.id, r.title, r.owner, reload, eventDraft,
                    onBack = { nav.popBackStack() },
                    onAdd = { tab -> nav.navigate(Route.AddGuests(r.id, tab)) }, onLimit = { nav.navigate(Route.Purchase) },
                )
            }
            composable<Route.AddGuests> {
                val r = it.toRoute<Route.AddGuests>()
                AddGuestScreen(
                    r.eventId, r.tab, onBack = { nav.popBackStack() },
                    onPremium = { nav.navigate(Route.Templates(r.eventId)) },
                    onAddon = { nav.navigate(Route.Purchase) },
                    onChanged = {
                        nav.previousBackStackEntry?.savedStateHandle?.let { h -> h[GUESTS_KEY] = (h.get<Int>(GUESTS_KEY) ?: 0) + 1 }
                        nav.markEventsChanged()
                    },
                )
            }
            composable<Route.Purchase> { ComingSoonScreen(context.getString(R.string.limit_addon), onBack = { nav.popBackStack() }) }
            composable<Route.Templates> { ComingSoonScreen(context.getString(R.string.create_success_choose_template), onBack = { nav.popBackStack() }) }
            composable<Route.JoinByCode> { ComingSoonScreen(context.getString(R.string.events_join), onBack = { nav.popBackStack() }) }
            composable<Route.Settings> {
                SettingsScreen(termsUrl = links.terms, privacyUrl = links.privacy, onBack = { nav.popBackStack() })
            }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter))
    }
}

private const val RELOAD_KEY = "events_reload"
private const val GUESTS_KEY = "guests_reload"

private fun NavHostController.markEventsChanged() {
    runCatching { getBackStackEntry<Route.Events>() }.getOrNull()?.savedStateHandle?.let { it[RELOAD_KEY] = (it.get<Int>(RELOAD_KEY) ?: 0) + 1 }
}

private fun NavHostController.resetTo(route: Route) {
    navigate(route) {
        popUpTo(graph.id) { inclusive = true }
        launchSingleTop = true
    }
}

data class LegalLinks(val terms: String, val privacy: String)

/** Legal pages on the guest site, in the UI language (web/public/legal; privacy arrives with T50). */
internal fun legalLinks(config: SupabaseConfig, language: AppLanguage): LegalLinks {
    val base = config.publicBaseUrl.trimEnd('/')
    val lang = language.effective
    return LegalLinks("$base/legal/terms/$lang.html", "$base/legal/privacy/$lang.html")
}
