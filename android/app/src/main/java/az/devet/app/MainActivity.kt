package az.devet.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import az.devet.app.ui.navigation.DevetNavHost
import az.devet.app.ui.theme.DevetTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DevetTheme {
                DevetNavHost()
            }
        }
    }
}
