package az.devet.app.ui.welcome

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import az.devet.app.R
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Shapes
import az.devet.app.ui.theme.Sizes
import az.devet.app.ui.theme.Spacing

/** Placeholder start screen for T41A: proves theme, fonts and the four string sets. Replaced by Sign in (T42). */
@Composable
fun WelcomeScreen() {
    val c = DevetTheme.colors
    val t = DevetTheme.type
    Box(
        Modifier
            .fillMaxSize()
            .background(c.bgCanvas)
            .safeDrawingPadding()
            .padding(horizontal = Spacing.gutter),
    ) {
        Column(
            Modifier.align(Alignment.Center).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.s1_5),
        ) {
            Box(
                Modifier.size(64.dp).background(c.bgSurface, CircleShape).border(1.dp, c.accentGold, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(R.string.app_name).take(1), style = t.serifTitle, color = c.brandPrimary)
            }
            Text(stringResource(R.string.app_name), style = t.serifDisplay, color = c.textPrimary)
            Text(stringResource(R.string.app_welcome), style = t.serifHeadline, color = c.textPrimary, modifier = Modifier.testTag("welcome"))
            Text(stringResource(R.string.app_tagline), style = t.callout, color = c.textSecondary, textAlign = TextAlign.Center)
            Spacer(Modifier.height(Spacing.s3))
            Button(
                onClick = {},
                modifier = Modifier.fillMaxWidth().heightIn(min = Sizes.controlHeight),
                shape = Shapes.control,
                colors = ButtonDefaults.buttonColors(containerColor = c.brandPrimary, contentColor = c.textOnBrand),
            ) {
                Text(stringResource(R.string.auth_login_title), style = t.headline)
            }
            Text(stringResource(R.string.app_language), style = t.footnote, color = c.textSecondary)
        }
    }
}


@Preview(name = "Light")
@Composable
private fun WelcomePreview() = DevetTheme(darkTheme = false) { WelcomeScreen() }

@Preview(name = "Dark")
@Composable
private fun WelcomeDarkPreview() = DevetTheme(darkTheme = true) { WelcomeScreen() }
