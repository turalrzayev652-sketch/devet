package az.devet.app.ui.send

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import az.devet.app.data.events.EventDraft
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/// Screens 8a → 8b: Preview list, then send flow.
@Composable
fun SendFlowScreen(
    eventId: String,
    event: EventDraft,
    onComplete: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showSend by remember { mutableStateOf(false) }

    if (showSend) {
        val sendVm: SendViewModel = koinViewModel { parametersOf(eventId) }
        SendScreen(
            sendVm,
            event.titleNames,
            event.type?.name?.lowercase() ?: "wedding",
            "https://devet.az",  // TODO: from config
            onComplete,
            modifier
        )
    } else {
        val previewVm: PreviewListViewModel = koinViewModel { parametersOf(eventId) }
        PreviewListScreen(
            previewVm,
            onReady = { showSend = true },
            modifier
        )
    }
}
