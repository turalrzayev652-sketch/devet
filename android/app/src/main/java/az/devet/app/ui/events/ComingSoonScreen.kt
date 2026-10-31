package az.devet.app.ui.events

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import az.devet.app.R
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing

/** Stand-in for screens of later modules (guests [6] — T45/T46, templates [4] — T44, join by code [11b] — T4A). */
@Composable
fun ComingSoonScreen(title: String?, onBack: () -> Unit) {
    val c = DevetTheme.colors
    Column(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding().testTag("comingSoon")) {
        Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
        Column(
            Modifier.fillMaxSize().padding(Spacing.gutter),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.s1_5, Alignment.CenterVertically),
        ) {
            if (title != null) Text(title, style = DevetTheme.type.serifTitle, color = c.textPrimary, textAlign = TextAlign.Center)
            Text(stringResource(R.string.common_coming_soon), style = DevetTheme.type.callout, color = c.textSecondary, textAlign = TextAlign.Center)
        }
    }
}
