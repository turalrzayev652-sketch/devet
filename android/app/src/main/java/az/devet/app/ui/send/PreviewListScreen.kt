package az.devet.app.ui.send

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SurfaceDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import az.devet.app.R
import az.devet.app.data.guests.Guest
import az.devet.app.data.guests.PreviewImage
import az.devet.app.ui.theme.Spacing
import coil.compose.AsyncImage

/// Screen 8a: "Adları yoxlayın" (screens.md §8a).
@Composable
fun PreviewListScreen(
    viewModel: PreviewListViewModel,
    onReady: () -> Unit,  // Hamısı yükləndikdən sonra send flow-a keç
    modifier: Modifier = Modifier
) {
    val state = viewModel.state.collectAsState().value

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Title
        Text(
            text = stringResource(R.string.send_preview_title),  // "Adları yoxlayın"
            style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md)
        )

        // Warnings
        if (state.warnings.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.md),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                state.warnings.forEach { warning ->
                    val label = when (warning.type) {
                        "no_phone" -> stringResource(R.string.send_warning_no_phone, warning.count)
                        "empty_name" -> stringResource(R.string.send_warning_empty_name, warning.count)
                        else -> ""
                    }
                    Text(
                        text = label,
                        fontSize = 12.sp,
                        color = Color.White,
                        modifier = Modifier
                            .background(Color(0xFFD97706), shape = RoundedCornerShape(16.dp))
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(Spacing.md))
        }

        // Upload progress
        if (!state.allReady) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Spacing.md),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                CircularProgressIndicator(modifier = Modifier.size(40.dp))
                Spacer(modifier = Modifier.height(Spacing.sm))
                Text(
                    text = stringResource(R.string.send_preview_generating),
                    fontSize = 14.sp
                )
                Text(
                    text = state.uploadProgress,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.outline
                )
            }
            return  // Don't show list while uploading
        }

        if (state.uploadError != null) {
            Text(
                text = stringResource(R.string.common_error_network),
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(Spacing.md)
            )
            Button(
                onClick = { viewModel.load() },
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(Spacing.md)
            ) {
                Text(stringResource(R.string.send_retry_upload))
            }
            return
        }

        // Guest list with previews
        LazyColumn(
            contentPadding = PaddingValues(bottom = Spacing.lg),
            modifier = Modifier.weight(1f)
        ) {
            items(state.guests) { guest ->
                PreviewListRow(
                    guest = guest,
                    preview = state.previews[guest.code]
                )
            }
        }

        // "Hamısı düzgündür — başla" button
        Button(
            onClick = onReady,
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md)
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary
            )
        ) {
            Text(
                text = stringResource(R.string.send_ready_button),
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun PreviewListRow(
    guest: Guest,
    preview: PreviewImage?,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        // Preview thumbnail (1200×630 → 120×63)
        if (preview != null) {
            AsyncImage(
                model = preview.bitmap,
                contentDescription = null,
                modifier = Modifier
                    .size(120.dp, 63.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(4.dp)
                    ),
                contentScale = ContentScale.Crop
            )
        } else {
            // Placeholder while generating
            Text(
                text = "…",
                modifier = Modifier
                    .size(120.dp, 63.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(4.dp)
                    ),
                fontSize = 32.sp
            )
        }

        // Name + phone
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = guest.name,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = if (guest.name.isBlank()) MaterialTheme.colorScheme.error else Color.Unspecified
            )
            if (guest.phoneE164 != null && guest.phoneE164.isNotEmpty()) {
                Text(
                    text = guest.phoneE164,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.outline
                )
            } else {
                Text(
                    text = "Telefon yoxdur",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}
