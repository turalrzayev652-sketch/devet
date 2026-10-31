package az.devet.app.ui.events

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import az.devet.app.R
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing

/** Screen [2] shell: title and the profile button to Settings. Event list comes in T43. */
@Composable
fun EventsScreen(onSettings: () -> Unit) {
    val c = DevetTheme.colors
    Column(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding().padding(horizontal = Spacing.gutter)) {
        Row(Modifier.fillMaxWidth().padding(top = Spacing.s2), verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.events_title), style = DevetTheme.type.serifDisplay, color = c.textPrimary,
                modifier = Modifier.weight(1f).testTag("eventsTitle"),
            )
            IconButton(onClick = onSettings, modifier = Modifier.testTag("settings")) {
                Icon(DevetIcons.user, contentDescription = stringResource(R.string.settings_title), tint = c.textPrimary)
            }
        }
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.common_coming_soon), style = DevetTheme.type.callout, color = c.textSecondary, textAlign = TextAlign.Center)
        }
    }
}
