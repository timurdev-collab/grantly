package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

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
                    Text(task.title, Modifier.weight(1f).padding(top = 13.dp))
                    if (task.taskKey == null) {
                        TextButton(enabled = !busy, onClick = {
                            busy = true
                            error = null
                            scope.launch {
                                try {
                                    ApplicationTasksRepository.deleteCustom(task)
                                    refresh++
                                } catch (cancelled: CancellationException) {
                                    throw cancelled
                                } catch (failure: Exception) {
                                    error = failure.message ?: "Could not delete task."
                                } finally {
                                    busy = false
                                }
                            }
                        }) { Text("Delete") }
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
}
