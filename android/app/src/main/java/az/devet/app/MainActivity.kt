package az.devet.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import az.devet.app.ui.AppViewModel
import az.devet.app.ui.navigation.DevetNavHost
import az.devet.app.ui.theme.DevetTheme
import org.koin.androidx.viewmodel.ext.android.viewModel

// AppCompatActivity: per-app language (Settings → "Tətbiqin dili") applies on Android < 13 too.
class MainActivity : AppCompatActivity() {
    private val app: AppViewModel by viewModel()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) app.handleLink(intent?.dataString)
        setContent {
            DevetTheme {
                DevetNavHost(app)
            }
        }
    }

    // E-mail links (az.devet.app://auth/…) while the app is open; launchMode singleTask in the manifest.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        app.handleLink(intent.dataString)
    }
}
