package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException

private val trackerInk = Color(0xFF19372B)
private val trackerForest = Color(0xFF123E30)

/** Read-only first pass at the iOS saved-scholarship application tracker. */
@Composable
internal fun SavedScholarshipsContent() {
    val session = AuthRepository.session
    Text("Applications", fontFamily = FontFamily.Serif, fontSize = 34.sp, color = trackerInk)
    Spacer(Modifier.height(8.dp))
    Text("Your saved scholarships and application stages", color = trackerInk.copy(alpha = .7f))
    Spacer(Modifier.height(20.dp))

    if (session == null) {
        Text("Sign in on the Profile tab to see your saved scholarships.", color = trackerInk)
        return
    }

    var items by remember(session.userId) { mutableStateOf<List<SavedScholarshipSummary>>(emptyList()) }
    var loading by remember(session.userId) { mutableStateOf(true) }
    var error by remember(session.userId) { mutableStateOf<String?>(null) }
    var retry by remember(session.userId) { mutableIntStateOf(0) }

    LaunchedEffect(session.userId, retry) {
        loading = true
        error = null
        try {
            items = SavedScholarshipsRepository.load()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load your applications."
        } finally {
            loading = false
        }
    }

    OutlinedButton(onClick = { retry++ }, enabled = !loading) { Text("Refresh") }
    Spacer(Modifier.height(12.dp))
    when {
        loading -> CircularProgressIndicator(color = trackerForest)
        error != null -> Text(error ?: "", color = MaterialTheme.colorScheme.error)
        items.isEmpty() -> Text("No saved scholarships yet. Browse Explore to find opportunities.", color = trackerInk)
        else -> {
            Text("${items.size} saved scholarships", color = trackerForest, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(12.dp))
            items.forEach { item ->
                Card(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(item.title, color = trackerInk, fontWeight = FontWeight.SemiBold)
                        if (item.provider.isNotBlank()) {
                            Text(item.provider, color = trackerInk.copy(alpha = .7f), fontSize = 13.sp)
                        }
                        if (item.country.isNotBlank()) {
                            Text(item.country, color = trackerInk.copy(alpha = .7f), fontSize = 12.sp)
                        }
                        Spacer(Modifier.height(8.dp))
                        Text("Status: ${item.status}", color = trackerForest, fontSize = 13.sp)
                        item.notes?.let { note ->
                            Spacer(Modifier.height(6.dp))
                            Text(note, color = trackerInk.copy(alpha = .7f), fontSize = 12.sp)
                        }
                    }
                }
            }
            Text(
                "Preview: showing up to 100 saved items. Editing, tasks and documents are not yet available.",
                color = trackerInk.copy(alpha = .65f),
                fontSize = 12.sp
            )
        }
    }
}
