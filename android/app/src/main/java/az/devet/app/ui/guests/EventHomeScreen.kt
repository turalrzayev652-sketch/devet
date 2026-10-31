package az.devet.app.ui.guests

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import az.devet.app.R
import az.devet.app.data.auth.AuthResult
import az.devet.app.data.guests.GuestRepository
import az.devet.app.ui.components.BackButton
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.components.LinkButton
import az.devet.app.ui.components.PrimaryButton
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing
import org.koin.compose.koinInject

/**
 * Inside an event until the guest list (screen [6], T46) exists: guest count and the three ways to add guests
 * (the empty state of [6], screens.md §6).
 */
@Composable
fun EventHomeScreen(eventId: String, title: String, reloadKey: Int, onBack: () -> Unit, onAdd: (tab: Int) -> Unit) {
    val c = DevetTheme.colors
    val repo: GuestRepository = koinInject()
    var count by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(eventId, reloadKey) { count = (repo.count(eventId) as? AuthResult.Ok)?.value }
    Column(Modifier.fillMaxSize().background(c.bgCanvas).safeDrawingPadding()) {
        Box(Modifier.padding(start = Spacing.s1, top = Spacing.s0_5)) { BackButton(onBack) }
        Column(
            Modifier.fillMaxSize().padding(Spacing.gutter),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.s1_5, Alignment.CenterVertically),
        ) {
            Text(title, style = DevetTheme.type.serifTitle, color = c.textPrimary, textAlign = TextAlign.Center)
            val n = count
            if (n != null && n > 0) {
                Text(pluralStringResource(R.plurals.guests_count, n, n), style = DevetTheme.type.title2, color = c.brandPrimary, modifier = Modifier.testTag("guestCount"))
                Text(stringResource(R.string.common_coming_soon), style = DevetTheme.type.footnote, color = c.textSecondary, textAlign = TextAlign.Center)
            } else {
                Icon(DevetIcons.envelope, null, tint = c.accentGold, modifier = Modifier.size(160.dp, 124.dp))
                Text(stringResource(R.string.guests_empty_title), style = DevetTheme.type.serifHeadline, color = c.textPrimary)
                Text(stringResource(R.string.guests_empty_body), style = DevetTheme.type.body, color = c.textSecondary, textAlign = TextAlign.Center)
            }
            Spacer(Modifier.height(Spacing.s2))
            PrimaryButton(stringResource(R.string.guests_add_manual), { onAdd(0) }, modifier = Modifier.testTag("addManual"))
            LinkButton(stringResource(R.string.guests_add_contacts), { onAdd(1) })
            LinkButton(stringResource(R.string.guests_add_excel), { onAdd(2) })
        }
    }
}
