package az.devet.app.ui.events

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing
import kotlinx.coroutines.launch

/// Screen: Ortaq ailə kodu ilə qoşulma (T4AA minimal).
@Composable
fun JoinCohostScreen(
    onJoin: suspend (token: String) -> Boolean,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    var token by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(DevetTheme.colors.bgCanvas)
            .padding(Spacing.gutter),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            "Ortaq ailə kodu",
            style = DevetTheme.type.serifTitle,
            color = DevetTheme.colors.textPrimary
        )
        Spacer(modifier = Modifier.height(Spacing.s1))

        OutlinedTextField(
            value = token,
            onValueChange = { token = it },
            label = { Text("Kod") },
            visualTransformation = PasswordVisualTransformation(),
            enabled = !loading,
            modifier = Modifier.fillMaxWidth()
        )

        if (error != null) {
            Spacer(modifier = Modifier.height(Spacing.s1))
            Text(
                error!!,
                color = DevetTheme.colors.feedbackDanger,
                style = DevetTheme.type.body
            )
        }

        Spacer(modifier = Modifier.height(Spacing.s1_5))

        Button(
            onClick = {
                if (token.isBlank()) {
                    error = "Kod boş ola bilməz"
                    return@Button
                }
                loading = true
                scope.launch {
                    val success = onJoin(token)
                    loading = false
                    if (!success) {
                        error = "Kod yanlış və ya istifadə olunub"
                    }
                }
            },
            enabled = !loading,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (loading) {
                CircularProgressIndicator(modifier = Modifier.padding(Spacing.s0_5))
            } else {
                Text("Qoşul")
            }
        }
    }
}
