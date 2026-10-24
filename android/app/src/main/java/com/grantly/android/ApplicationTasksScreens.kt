package com.grantly.android

import android.app.DatePickerDialog
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.time.LocalDate

/** Expandable checklist in each saved scholarship's application card. */
@Composable
internal fun ApplicationTaskControls(scholarshipId: String) {
    val userId = AuthRepository.session?.userId
    var expanded by remember(userId, scholarshipId) { mutableStateOf(false) }
    var tasks by remember(userId, scholarshipId) { mutableStateOf<List<ApplicationTaskItem>>(emptyList()) }
    var loading by remember(userId, scholarshipId) { mutableStateOf(false) }
    var busy by remember(userId, scholarshipId) { mutableStateOf(false) }
    var error by remember(userId, scholarshipId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId, scholarshipId) { mutableIntStateOf(0) }
    var adding by remember(userId, scholarshipId) { mutableStateOf(false) }
    var draft by remember(userId, scholarshipId) { mutableStateOf("") }
    var editingDue by remember(userId, scholarshipId) { mutableStateOf<ApplicationTaskItem?>(null) }
    var dueDraft by remember(userId, scholarshipId) { mutableStateOf<LocalDate?>(null) }
    var deletingTask by remember(userId, scholarshipId) { mutableStateOf<ApplicationTaskItem?>(null) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    OutlinedButton(onClick = { expanded = !expanded }, enabled = !busy) {
        Text(if (expanded) "Hide checklist" else "Application checklist")
    }
    if (!expanded || userId == null) return

    LaunchedEffect(userId, scholarshipId, refresh, expanded) {
        loading = true
        error = null
        try {
            tasks = ApplicationTasksRepository.load(scholarshipId)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load checklist."
        } finally {
            loading = false
        }
    }

    Spacer(Modifier.height(8.dp))
    Text("Checklist: " + tasks.count { it.completed } + " / " + tasks.size + " complete")
    if (loading) {
        CircularProgressIndicator(Modifier.size(24.dp))
    } else {
        error?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
            TextButton(onClick = { refresh++ }, enabled = !busy) { Text("Retry") }
        }
        if (error == null) {
            tasks.forEach { task ->
                Row(Modifier.fillMaxWidth()) {
                    Checkbox(
                        checked = task.completed,
                        enabled = !busy,
                        onCheckedChange = { checked ->
                            busy = true
                            error = null
                            scope.launch {
                                try {
                                    ApplicationTasksRepository.setCompleted(task.id, checked)
                                    refresh++
                                } catch (cancelled: CancellationException) {
                                    throw cancelled
                                } catch (failure: Exception) {
                                    error = failure.message ?: "Could not update task."
                                } finally {
                                    busy = false
                                }
                            }
                        }
                    )
                    Column(Modifier.weight(1f).padding(top = 8.dp)) {
                        Text(task.title)
                        task.dueDate?.let { Text("Due: $it", style = MaterialTheme.typography.bodySmall) }
                        TextButton(enabled = !busy, onClick = {
                            dueDraft = task.dueDate
                            editingDue = task
                        }) { Text(if (task.dueDate == null) "Set due date" else "Edit due date") }
                    }
                    if (task.taskKey == null) {
                        TextButton(enabled = !busy, onClick = { deletingTask = task }) { Text("Delete") }
                    }
                }
            }
            TextButton(enabled = !busy, onClick = { draft = ""; adding = true }) {
                Text("+ Add checklist item")
            }
        }
    }

    if (adding) {
        AlertDialog(
            onDismissRequest = { if (!busy) adding = false },
            title = { Text("Add checklist item") },
            text = {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { if (it.length <= 180) draft = it },
                    label = { Text("Task") },
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(enabled = !busy && draft.isNotBlank(), onClick = {
                    busy = true
                    error = null
                    scope.launch {
                        try {
                            ApplicationTasksRepository.add(
                                scholarshipId, draft, (tasks.maxOfOrNull { it.position } ?: 0) + 10
                            )
                            adding = false
                            refresh++
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Could not add task."
                        } finally {
                            busy = false
                        }
                    }
                }) { Text("Add") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { adding = false }) { Text("Cancel") }
            }
        )
    }

    editingDue?.let { task ->
        AlertDialog(
            onDismissRequest = { if (!busy) editingDue = null },
            title = { Text("Checklist due date") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(task.title)
                    Text("Choose a personal due date. Dates use your device's current time zone.")
                    OutlinedButton(enabled = !busy, onClick = {
                        val initial = dueDraft ?: LocalDate.now()
                        DatePickerDialog(
                            context,
                            { _, year, month, day -> dueDraft = LocalDate.of(year, month + 1, day) },
                            initial.year, initial.monthValue - 1, initial.dayOfMonth
                        ).show()
                    }) { Text(dueDraft?.toString() ?: "Choose a date") }
                    if (dueDraft != null) {
                        TextButton(enabled = !busy, onClick = { dueDraft = null }) { Text("Clear due date") }
                    }
                    Text("This does not schedule a notification.", style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = {
                TextButton(enabled = !busy, onClick = {
                    busy = true
                    error = null
                    val selected = dueDraft
                    scope.launch {
                        try {
                            ApplicationTasksRepository.setDueDate(task.id, selected)
                            editingDue = null
                            refresh++
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Could not save due date."
                        } finally {
                            busy = false
                        }
                    }
                }) { Text(if (busy) "Saving…" else "Save") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { editingDue = null }) { Text("Cancel") }
            }
        )
    }

    deletingTask?.let { task ->
        AlertDialog(
            onDismissRequest = { if (!busy) deletingTask = null },
            title = { Text("Delete checklist item?") },
            text = { Text("Delete \"${task.title}\"? This cannot be undone.") },
            confirmButton = {
                TextButton(enabled = !busy, onClick = {
                    busy = true
                    error = null
                    scope.launch {
                        try {
                            ApplicationTasksRepository.deleteCustom(task)
                            deletingTask = null
                            refresh++
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Could not delete task."
                        } finally {
                            busy = false
                        }
                    }
                }) { Text(if (busy) "Deleting…" else "Delete") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { deletingTask = null }) { Text("Cancel") }
            }
        )
    }
}
