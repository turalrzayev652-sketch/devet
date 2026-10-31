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
            composable<Route.Events> { EventsScreen(onSettings = { nav.navigate(Route.Settings) }) }
            composable<Route.Settings> {
                SettingsScreen(termsUrl = links.terms, privacyUrl = links.privacy, onBack = { nav.popBackStack() })
            }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter))
    }
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
