package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import kotlinx.coroutines.launch

private val trackerInk = Color(0xFF19372B)
private val trackerForest = Color(0xFF123E30)

/** Signed-in scholarship tracker with status and notes editing. */
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
    var editingStatus by remember(session.userId) { mutableStateOf<SavedScholarshipSummary?>(null) }
    var editingNotes by remember(session.userId) { mutableStateOf<SavedScholarshipSummary?>(null) }
    var noteDraft by remember(session.userId) { mutableStateOf("") }
    var mutationBusy by remember(session.userId) { mutableStateOf(false) }
    var mutationError by remember(session.userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

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

    OutlinedButton(onClick = { retry++ }, enabled = !loading && !mutationBusy) { Text("Refresh") }
    if (mutationError != null) {
        Spacer(Modifier.height(8.dp))
        Text(mutationError ?: "", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
    }
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
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(enabled = !mutationBusy, onClick = {
                                mutationError = null
                                editingStatus = item
                            }) { Text("Change status") }
                            TextButton(enabled = !mutationBusy, onClick = {
                                mutationError = null
                                noteDraft = item.notes.orEmpty()
                                editingNotes = item
                            }) { Text("Edit note") }
                        }
                        Spacer(Modifier.height(8.dp))
                        ApplicationTaskControls(item.scholarshipId)
                        Spacer(Modifier.height(8.dp))
                        ApplicationDocumentControls(item.scholarshipId)
                    }
                }
            }
            Text(
                "Preview: showing up to 100 saved items. Document metadata is read-only.",
                color = trackerInk.copy(alpha = .65f),
                fontSize = 12.sp
            )
        }
    }

    editingStatus?.let { item ->
        AlertDialog(
            onDismissRequest = { if (!mutationBusy) editingStatus = null },
            title = { Text("Application status") },
            text = {
                Column(Modifier.heightIn(max = 370.dp).verticalScroll(rememberScrollState())) {
                    listOf("Planning", "Preparing", "Submitted", "Applied", "Interview",
                        "Offer", "Rejected", "Withdrawn", "Result").forEach { status ->
                        TextButton(
                            enabled = !mutationBusy,
                            onClick = {
                                mutationBusy = true
                                mutationError = null
                                scope.launch {
                                    try {
                                        SavedScholarshipsRepository.updateStatus(item.scholarshipId, status)
                                        items = items.map { if (it.scholarshipId == item.scholarshipId) it.copy(status = status) else it }
                                        editingStatus = null
                                    } catch (cancelled: CancellationException) {
                                        throw cancelled
                                    } catch (failure: Exception) {
                                        mutationError = failure.message ?: "Unable to update status."
                                    } finally {
                                        mutationBusy = false
                                    }
                                }
                            }
                        ) { Text(if (item.status == status) "✓ $status" else status) }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(enabled = !mutationBusy, onClick = { editingStatus = null }) { Text("Cancel") } }
        )
    }

    editingNotes?.let { item ->
        AlertDialog(
            onDismissRequest = { if (!mutationBusy) editingNotes = null },
            title = { Text("Application note") },
            text = {
                OutlinedTextField(
                    value = noteDraft,
                    onValueChange = { if (it.length <= 10_000) noteDraft = it },
                    label = { Text("Notes") },
                    minLines = 4,
                    maxLines = 8,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(enabled = !mutationBusy, onClick = {
                    mutationBusy = true
                    mutationError = null
                    scope.launch {
                        try {
                            SavedScholarshipsRepository.updateNotes(item.scholarshipId, noteDraft)
                            items = items.map {
                                if (it.scholarshipId == item.scholarshipId)
                                    it.copy(notes = noteDraft.ifBlank { null })
                                else it
                            }
                            editingNotes = null
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            mutationError = failure.message ?: "Unable to update notes."
                        } finally {
                            mutationBusy = false
                        }
                    }
                }) { Text(if (mutationBusy) "Saving…" else "Save") }
            },
            dismissButton = { TextButton(enabled = !mutationBusy, onClick = { editingNotes = null }) { Text("Cancel") } }
        )
    }

}
