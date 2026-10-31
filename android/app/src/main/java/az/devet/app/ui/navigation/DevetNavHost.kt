package az.devet.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import az.devet.app.ui.welcome.WelcomeScreen
import kotlinx.serialization.Serializable

/** Type-safe routes. Screens from spec/screens.md are added here module by module (T42+). */
sealed interface Route {
    @Serializable data object Welcome : Route
}

@Composable
fun DevetNavHost() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = Route.Welcome) {
        composable<Route.Welcome> { WelcomeScreen() }
    }
}
