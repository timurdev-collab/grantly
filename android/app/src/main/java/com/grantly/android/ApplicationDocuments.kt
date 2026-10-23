package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID

internal data class ApplicationDocumentItem(
    val id: String,
    val fileName: String,
    val contentType: String?,
    val byteSize: Long?
)

/**
 * Read-only private document metadata from the existing application_documents table.
 * Storage objects are deliberately not downloaded or exposed through public URLs.
 */
internal object ApplicationDocumentsRepository {
    suspend fun load(scholarshipId: String): List<ApplicationDocumentItem> = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val userId = try { UUID.fromString(session.userId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
        val scholarship = try { UUID.fromString(scholarshipId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid scholarship identifier.") }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Document vault is not configured.")
        }
        fun enc(value: String) = URLEncoder.encode(value, "UTF-8")
        val query = "select=id,file_name,content_type,byte_size" +
            "&user_id=eq." + enc(userId) +
            "&scholarship_id=eq." + enc(scholarship) +
            "&order=created_at.desc&limit=100"
        val connection = URL("$base/rest/v1/application_documents?$query")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            val status = connection.responseCode
            if (status !in 200..299) throw IOException(
                if (status == 401 || status == 403) "Sign in again to access private documents."
                else "Unable to load documents (HTTP $status)."
            )
            val rows = JSONArray(connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            buildList {
                for (i in 0 until rows.length()) {
                    val row = rows.optJSONObject(i) ?: continue
                    val id = row.optString("id")
                    if (id.isBlank()) continue
                    add(ApplicationDocumentItem(
                        id = id,
                        fileName = row.optString("file_name").ifBlank { "Document" },
                        contentType = row.optString("content_type").takeUnless {
                            row.isNull("content_type") || it.isBlank()
                        },
                        byteSize = if (row.isNull("byte_size")) null else row.optLong("byte_size")
                    ))
                }
            }
        } finally {
            connection.disconnect()
        }
    }
}

/** Metadata-only preview; no sensitive document contents leave the private storage bucket. */
@Composable
internal fun ApplicationDocumentControls(scholarshipId: String) {
    val userId = AuthRepository.session?.userId
    var expanded by remember(userId, scholarshipId) { mutableStateOf(false) }
    var loading by remember(userId, scholarshipId) { mutableStateOf(false) }
    var documents by remember(userId, scholarshipId) {
        mutableStateOf<List<ApplicationDocumentItem>>(emptyList())
    }
    var error by remember(userId, scholarshipId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId, scholarshipId) { mutableIntStateOf(0) }

    OutlinedButton(onClick = { expanded = !expanded }) {
        Text(if (expanded) "Hide documents" else "Private documents")
    }
    if (!expanded || userId == null) return

    LaunchedEffect(userId, scholarshipId, refresh) {
        loading = true
        error = null
        try {
            documents = ApplicationDocumentsRepository.load(scholarshipId)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            documents = emptyList()
            error = failure.message ?: "Unable to load documents."
        } finally {
            loading = false
        }
    }

    Spacer(Modifier.height(8.dp))
    when {
        loading -> CircularProgressIndicator(Modifier.size(24.dp))
        error != null -> {
            Text(error ?: "", color = MaterialTheme.colorScheme.error)
            TextButton(onClick = { refresh++ }) { Text("Retry") }
        }
        documents.isEmpty() -> Text("No documents uploaded for this application.")
        else -> {
            Text("${documents.size} private document(s)")
            documents.forEach { doc ->
                Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                    Text(doc.fileName, style = MaterialTheme.typography.bodyMedium)
                    val size = doc.byteSize?.let { "${(it + 1023) / 1024} KB" } ?: "Size unavailable"
                    Text(
                        listOfNotNull(doc.contentType, size).joinToString(" · "),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
    }
    Text(
        "Preview: document names only. Upload, download and deletion are not yet supported on Android.",
        style = MaterialTheme.typography.bodySmall
    )
}
