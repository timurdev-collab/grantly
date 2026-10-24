package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** iOS-equivalent safety controls backed by existing RLS-protected tables. */
internal object AdvisorMessageSafetyRepository {
    private val reasons = setOf("Spam", "Harassment", "Inappropriate content", "Scam or fraud", "Other")
    val reportReasons: List<String> = reasons.toList()

    private fun validId(id: String): String = try {
        UUID.fromString(id).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid account or message identifier.")
    }

    private suspend fun request(path: String, method: String, body: JSONObject? = null): String {
        val session = AuthRepository.activeSession()
        return withContext(Dispatchers.IO) {
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Safety service is not configured.")
            }
            val connection = URL(base + path).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                connection.setRequestProperty("Accept", "application/json")
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Prefer", "return=minimal")
                    connection.outputStream.use {
                        it.write(body.toString().toByteArray(Charsets.UTF_8))
                    }
                }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401, 403 -> "You do not have permission for this safety action. Sign in again if needed."
                        409 -> "This safety action has already been recorded."
                        429 -> "Too many requests. Please try again later."
                        else -> "Safety action failed (HTTP " + status + "). Please retry."
                    })
                }
                connection.inputStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            } finally {
                connection.disconnect()
            }
        }
    }

    suspend fun blockedUserIds(): Set<String> {
        val me = validId(AuthRepository.activeSession().userId)
        val rows = JSONArray(request(
            "/rest/v1/user_blocks?select=blocked_id&blocker_id=eq." + me,
            "GET"
        ))
        return buildSet {
            for (i in 0 until rows.length()) {
                val id = rows.optJSONObject(i)?.optString("blocked_id").orEmpty()
                runCatching { validId(id) }.getOrNull()?.let { add(it) }
            }
        }
    }

    suspend fun block(userId: String) {
        val me = validId(AuthRepository.activeSession().userId)
        val other = validId(userId)
        require(me != other) { "You cannot block yourself." }
        request("/rest/v1/user_blocks", "POST",
            JSONObject().put("blocker_id", me).put("blocked_id", other))
    }

    suspend fun unblock(userId: String) {
        val me = validId(AuthRepository.activeSession().userId)
        val other = validId(userId)
        request("/rest/v1/user_blocks?blocker_id=eq." + me + "&blocked_id=eq." + other, "DELETE")
    }

    suspend fun report(userId: String, messageId: String?, reason: String, details: String) {
        val me = validId(AuthRepository.activeSession().userId)
        val other = validId(userId)
        require(me != other) { "You cannot report yourself." }
        require(reason in reasons) { "Select a valid report reason." }
        require(details.length <= 1000) { "Report details must be at most 1,000 characters." }
        request("/rest/v1/safety_reports", "POST",
            JSONObject()
                .put("reporter_id", me)
                .put("reported_user_id", other)
                .put("message_id", messageId?.let(::validId) ?: JSONObject.NULL)
                .put("reason", reason)
                .put("details", details.trim()))
    }
}

@Composable
internal fun AdvisorMessageSafetyControls(
    otherUserId: String?,
    reportMessage: AdvisorMessage?,
    onReportHandled: () -> Unit,
    onBlockChanged: (Boolean) -> Unit
) {
    val currentUserId = AuthRepository.session?.userId
    val scope = rememberCoroutineScope()
    var blocked by remember(currentUserId, otherUserId) { mutableStateOf(false) }
    var busy by remember(currentUserId, otherUserId) { mutableStateOf(false) }
    var error by remember(currentUserId, otherUserId) { mutableStateOf<String?>(null) }
    var notice by remember(currentUserId, otherUserId) { mutableStateOf<String?>(null) }
    var confirmBlock by remember(currentUserId, otherUserId) { mutableStateOf(false) }
    var showReport by remember(currentUserId, otherUserId) { mutableStateOf(false) }
    var targetMessage by remember(currentUserId, otherUserId) { mutableStateOf<AdvisorMessage?>(null) }
    var reason by remember(currentUserId, otherUserId) { mutableStateOf("Spam") }
    var details by remember(currentUserId, otherUserId) { mutableStateOf("") }

    LaunchedEffect(currentUserId, otherUserId) {
        if (currentUserId != null && otherUserId != null) {
            try {
                val isBlocked = otherUserId in AdvisorMessageSafetyRepository.blockedUserIds()
                if (AuthRepository.session?.userId == currentUserId) {
                    blocked = isBlocked
                    onBlockChanged(isBlocked)
                }
            } catch (failure: Exception) {
                error = failure.message ?: "Could not load blocked users."
            }
        }
    }
    LaunchedEffect(reportMessage?.id) {
        if (reportMessage != null) {
            targetMessage = reportMessage
            reason = "Spam"
            details = ""
            showReport = true
            onReportHandled()
        }
    }
    if (otherUserId == null || otherUserId == currentUserId) {
        Text("Safety controls are available after the other participant is identified.",
            style = MaterialTheme.typography.bodySmall)
        return
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = {
            error = null
            if (blocked) {
                busy = true
                scope.launch {
                    try {
                        AdvisorMessageSafetyRepository.unblock(otherUserId)
                        blocked = false
                        onBlockChanged(false)
                        notice = "User unblocked."
                    } catch (failure: Exception) {
                        error = failure.message ?: "Could not unblock user."
                    } finally {
                        busy = false
                    }
                }
            } else {
                confirmBlock = true
            }
        }, enabled = !busy) {
            Text(if (blocked) "Unblock user" else "Block user")
        }
        OutlinedButton(onClick = {
            targetMessage = null
            reason = "Spam"
            details = ""
            showReport = true
        }, enabled = !busy) { Text("Report user") }
    }
    if (notice != null) Text(notice.orEmpty(), style = MaterialTheme.typography.bodySmall)
    if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
    if (confirmBlock) {
        AlertDialog(
            onDismissRequest = { confirmBlock = false },
            title = { Text("Block this user?") },
            text = { Text("Blocking prevents messages between your accounts. You can unblock later.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmBlock = false
                    busy = true
                    scope.launch {
                        try {
                            AdvisorMessageSafetyRepository.block(otherUserId)
                            blocked = true
                            onBlockChanged(true)
                            notice = "User blocked. Messaging is disabled."
                        } catch (failure: Exception) {
                            error = failure.message ?: "Could not block user."
                        } finally {
                            busy = false
                        }
                    }
                }) { Text("Block") }
            },
            dismissButton = {
                TextButton(onClick = { confirmBlock = false }) { Text("Cancel") }
            }
        )
    }
    if (showReport) {
        AlertDialog(
            onDismissRequest = { if (!busy) showReport = false },
            title = { Text(if (targetMessage == null) "Report user" else "Report message") },
            text = {
                Column {
                    Text("Choose a reason for our safety team:")
                    AdvisorMessageSafetyRepository.reportReasons.forEach { option ->
                        Row(Modifier.fillMaxWidth().clickable(enabled = !busy) { reason = option }) {
                            RadioButton(selected = reason == option, onClick = { reason = option },
                                enabled = !busy)
                            Text(option, modifier = Modifier.padding(top = 12.dp))
                        }
                    }
                    OutlinedTextField(
                        value = details,
                        onValueChange = { if (it.length <= 1000) details = it },
                        label = { Text("Details (optional)") },
                        maxLines = 3,
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !busy
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    busy = true
                    error = null
                    scope.launch {
                        try {
                            AdvisorMessageSafetyRepository.report(
                                otherUserId, targetMessage?.id, reason, details
                            )
                            showReport = false
                            notice = "Report submitted to the safety team."
                        } catch (failure: Exception) {
                            error = failure.message ?: "Could not submit report."
                        } finally {
                            busy = false
                        }
                    }
                }, enabled = !busy) { Text(if (busy) "Submitting…" else "Submit report") }
            },
            dismissButton = {
                TextButton(onClick = { showReport = false }, enabled = !busy) { Text("Cancel") }
            }
        )
    }
}
