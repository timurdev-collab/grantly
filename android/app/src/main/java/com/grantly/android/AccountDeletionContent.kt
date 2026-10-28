package com.grantly.android

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * An explicit, irreversible account-deletion action for every signed-in role.
 * This is separate from the academic-profile load so deletion remains available
 * even when the profile record is missing or the profile service is unavailable.
 */
@Composable
internal fun AccountDeletionContent(userId: String) {
    val scope = rememberCoroutineScope()
    var confirm by remember(userId) { mutableStateOf(false) }
    var deleting by remember(userId) { mutableStateOf(false) }
    var error by remember(userId) { mutableStateOf<String?>(null) }

    Spacer(Modifier.height(10.dp))
    TextButton(enabled = !deleting, onClick = { error = null; confirm = true }) {
        Text(
            if (deleting) "Deleting account…" else "Delete account",
            color = MaterialTheme.colorScheme.error
        )
    }
    if (error != null) {
        Text(error ?: "", color = MaterialTheme.colorScheme.error)
    }

    if (confirm) {
        AlertDialog(
            onDismissRequest = { if (!deleting) confirm = false },
            title = { Text("Delete your EduT account?") },
            text = {
                Text(
                    "This permanently deletes your account, profile, saved scholarships, " +
                        "applications and messages. This cannot be undone."
                )
            },
            confirmButton = {
                TextButton(
                    enabled = !deleting,
                    onClick = {
                        deleting = true
                        error = null
                        scope.launch {
                            try {
                                AuthRepository.deleteAccount()
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                error = failure.message ?: "Unable to delete your account."
                            } finally {
                                deleting = false
                                confirm = false
                            }
                        }
                    }
                ) {
                    Text(
                        if (deleting) "Deleting…" else "Delete account",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            dismissButton = {
                TextButton(enabled = !deleting, onClick = { confirm = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
