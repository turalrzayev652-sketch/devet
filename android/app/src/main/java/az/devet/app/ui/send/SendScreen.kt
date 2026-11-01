package az.devet.app.ui.send

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import az.devet.app.R
import az.devet.app.ui.components.DevetIcons
import az.devet.app.ui.theme.DevetTheme
import az.devet.app.ui.theme.Spacing

/// Screen 8b: Qonaq-qonaq göndərmə axını (spec/screens.md §8b).
@Composable
fun SendScreen(
    viewModel: SendViewModel,
    eventTitle: String,
    eventType: String,
    baseUrl: String,
    onComplete: () -> Unit,  // Tamamlanan → [9] Statistika
    modifier: Modifier = Modifier
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showConfirmation by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(DevetTheme.colors.bgCanvas)
            .padding(horizontal = Spacing.gutter, vertical = Spacing.s1)
    ) {
        // Üst: İrəliləmə bar
        LinearProgressIndicator(
            progress = { if (state.guests.isEmpty()) 0f else state.sentCount.toFloat() / state.guests.size },
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp),
            color = DevetTheme.colors.brandPrimary,
            trackColor = DevetTheme.colors.bgSunken,
        )
        Text(
            "${state.sentCount} / ${state.guests.size} göndərildi",
            style = DevetTheme.type.footnote,
            color = DevetTheme.colors.textSecondary,
            modifier = Modifier.padding(top = Spacing.s0_5)
        )

        // Gündəlik xəbərdarlığı
        if (state.dailyWarning) {
            Text(
                "Bu gün çox mesaj göndərdiniz. Nömrənizin məhdudlaşdırılmaması üçün qalanını sabah davam etdirin.",
                style = DevetTheme.type.body,
                color = DevetTheme.colors.textPrimary,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(DevetTheme.colors.accentGoldSubtle, RoundedCornerShape(8.dp))
                    .padding(Spacing.s1)
            )
        }

        if (state.allDone) {
            // Tamamlandı ekranı
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Icon(
                    DevetIcons.check,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = DevetTheme.colors.brandPrimary
                )
                Spacer(modifier = Modifier.height(Spacing.s1))
                Text(
                    "Bütün dəvətlər göndərildi",
                    style = DevetTheme.type.serifHeadline,
                    color = DevetTheme.colors.textPrimary,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(Spacing.s2))
                Button(
                    onClick = onComplete,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = DevetTheme.colors.brandPrimary
                    )
                ) {
                    Text(
                        "Statistikaya bax",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
            return
        }

        val currentGuest = viewModel.currentGuest()
        if (currentGuest == null) {
            return
        }

        // Mərkəz: Böyük guest kartı
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Avatar + Ad
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .background(DevetTheme.colors.brandPrimary, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    currentGuest.name.take(2).uppercase(),
                    style = DevetTheme.type.serifTitle,
                    color = DevetTheme.colors.textOnBrand
                )
            }

            Spacer(modifier = Modifier.height(Spacing.s1))
            Text(
                currentGuest.name,
                style = DevetTheme.type.serifHeadline,
                color = DevetTheme.colors.textPrimary
            )

            Spacer(modifier = Modifier.height(Spacing.s0_5))
            Text(
                currentGuest.phoneE164 ?: "",
                style = DevetTheme.type.body,
                color = DevetTheme.colors.textSecondary
            )

            Spacer(modifier = Modifier.height(Spacing.s1_5))

            // WhatsApp önizləməsi (og:image + title placeholder)
            Text(
                "WhatsApp-da belə görünəcək:",
                style = DevetTheme.type.footnote,
                color = DevetTheme.colors.textSecondary
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(DevetTheme.colors.bgSunken, RoundedCornerShape(8.dp))
                    .padding(Spacing.s1)
            ) {
                Text(
                    eventTitle,
                    style = DevetTheme.type.headline,
                    color = DevetTheme.colors.textPrimary,
                    maxLines = 2
                )
            }

            Spacer(modifier = Modifier.height(Spacing.s1))

            // Mesaj metni
            Text(
                "Mesaj:",
                style = DevetTheme.type.footnote,
                color = DevetTheme.colors.textSecondary
            )
            val message = viewModel.buildWaMessage(
                currentGuest,
                eventTitle,
                eventType,
                currentGuest.lang ?: "az",
                baseUrl
            )
            Text(
                message,
                style = DevetTheme.type.body,
                color = DevetTheme.colors.textPrimary,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(DevetTheme.colors.bgSunken, RoundedCornerShape(8.dp))
                    .padding(Spacing.s1)
            )
        }

        Spacer(modifier = Modifier.height(Spacing.s1))

        // Düymələr
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.s1)
        ) {
            TextButton(
                onClick = { viewModel.skip() },
                modifier = Modifier
                    .weight(1f)
                    .height(48.dp)
            ) {
                Text("Keç")
            }

            Button(
                onClick = { showConfirmation = true },
                modifier = Modifier
                    .weight(1.5f)
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = DevetTheme.colors.brandPrimary
                )
            ) {
                Text(
                    "WhatsApp-da göndər",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }

    // Confirmation sheet
    if (showConfirmation) {
        ModalBottomSheet(
            onDismissRequest = { showConfirmation = false },
            sheetState = sheetState,
            containerColor = DevetTheme.colors.bgRaised
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Spacing.gutter),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    "Göndərildi?",
                    style = DevetTheme.type.serifHeadline,
                    color = DevetTheme.colors.textPrimary
                )

                Spacer(modifier = Modifier.height(Spacing.s1_5))

                Button(
                    onClick = {
                        viewModel.confirmSent(currentGuest)
                        showConfirmation = false
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = DevetTheme.colors.brandPrimary
                    )
                ) {
                    Text("Bəli, növbəti")
                }

                Spacer(modifier = Modifier.height(Spacing.s0_5))

                TextButton(
                    onClick = { showConfirmation = false },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Xeyr, yenidən")
                }

                Spacer(modifier = Modifier.height(Spacing.s1))
            }
        }
    }
}
