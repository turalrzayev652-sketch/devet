package az.devet.app.ui.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/// Screen [9]: Statistika (spec/screens.md §9, T49).
@Composable
fun StatsScreen(
    eventId: String,
    modifier: Modifier = Modifier
) {
    val vm: StatsViewModel = koinViewModel { parametersOf(eventId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val c = DevetTheme.colors

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(c.bgCanvas)
            .padding(Spacing.gutter)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(Spacing.s1)
    ) {
        Text(
            "Statistika",
            style = DevetTheme.type.serifTitle,
            color = c.textPrimary,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold
        )

        if (state.loading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(Spacing.s1),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
            return@Column
        }

        // 5 kart: Göndərildi, Baxdı, Gəlir, Gəlmir, Cavab yoxdur
        StatCard("Göndərildi", state.sent.toString(), c.brandPrimary)
        StatCard("Baxdı", state.viewed.toString(), c.accentGold)
        StatCard("Gəlir", "${state.coming} (${state.totalPeople} nəfər)", c.feedbackSuccess)
        StatCard("Gəlmir", state.declined.toString(), c.feedbackDanger)
        StatCard("Cavab yoxdur", state.noAnswer.toString(), c.textSecondary)

        Spacer(modifier = Modifier.height(Spacing.s1))

        // Funnel: göndərildi → baxdı → cavab verdi
        val funnelData = listOf(
            Triple("Göndərildi", state.sent, c.brandPrimary),
            Triple("Baxdı", state.viewed, c.accentGold),
            Triple("Cavab verdi", state.coming + state.declined, c.feedbackSuccess),
        )

        Text(
            "Dəvətlərin yolu",
            style = DevetTheme.type.headline,
            color = c.textPrimary,
            modifier = Modifier.padding(top = Spacing.s1)
        )

        for ((label, count, _) in funnelData) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = Spacing.s0_5),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.s1)
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(24.dp)
                        .background(c.accentGoldSubtle, RoundedCornerShape(4.dp))
                )
                Text("$label: $count", style = DevetTheme.type.body, color = c.textPrimary)
            }
        }
    }
}

@Composable
private fun StatCard(label: String, value: String, color: androidx.compose.ui.graphics.Color) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.1f)),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(Spacing.s1),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                label,
                style = DevetTheme.type.footnote,
                color = DevetTheme.colors.textSecondary
            )
            Text(
                value,
                style = DevetTheme.type.serifTitle,
                color = color,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
