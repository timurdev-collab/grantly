package com.grantly.android

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import java.util.UUID

internal data class ApplicationDocumentItem(
    val id: String,
    val fileName: String,
    val contentType: String?,
    val byteSize: Long?,
    val storagePath: String
)

/** User-scoped document metadata and private Storage operations; never creates public URLs. */
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
        val query = "select=id,file_name,content_type,byte_size,storage_path" +
            "&user_id=eq." + enc(userId) +
            "&scholarship_id=eq." + enc(scholarship) +
            "&order=created_at.desc&limit=100"
        val connection = URL("$base/rest/v1/application_documents?$query")
            .openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
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
                        byteSize = if (row.isNull("byte_size")) null else row.optLong("byte_size"),
                        storagePath = row.optString("storage_path")
                    ))
                }
            }
        } finally {
            connection.disconnect()
        }
    }
    /**
     * Remove a private document, matching the iOS storage-first deletion order.
     * A metadata deletion failure is reported so the user can retry cleanup.
     * The path is validated against the signed-in user's scholarship namespace.
     */
    suspend fun delete(scholarshipId: String, document: ApplicationDocumentItem) = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val userId = try { UUID.fromString(session.userId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
        val scholarship = try { UUID.fromString(scholarshipId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid scholarship identifier.") }
        val documentId = try { UUID.fromString(document.id).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid document identifier.") }
        val path = document.storagePath
        if (!path.startsWith("$userId/$scholarship/") ||
            path.length <= "$userId/$scholarship/".length ||
            path.contains("..") || path.contains(92.toChar())) {
            throw IOException("Document path does not belong to this application.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Document vault is not configured.")
        }
        val storage = URL("$base/storage/v1/object/application-documents")
            .openConnection() as HttpURLConnection
        storage.instanceFollowRedirects = false
        try {
            storage.requestMethod = "DELETE"
            storage.connectTimeout = 12_000
            storage.readTimeout = 15_000
            storage.doOutput = true
            storage.setRequestProperty("apikey", key)
            storage.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            storage.setRequestProperty("Content-Type", "application/json")
            val payload = JSONObject().put("prefixes", JSONArray().put(path))
            storage.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val code = storage.responseCode
            if (code !in 200..299) throw IOException(
                if (code == 401 || code == 403) "Sign in again to remove documents."
                else "Unable to remove private file (HTTP $code)."
            )
        } finally {
            storage.disconnect()
        }

        fun enc(value: String) = URLEncoder.encode(value, "UTF-8")
        val query = "id=eq.${enc(documentId)}&user_id=eq.${enc(userId)}" +
            "&scholarship_id=eq.${enc(scholarship)}"
        val metadata = URL("$base/rest/v1/application_documents?$query")
            .openConnection() as HttpURLConnection
        metadata.instanceFollowRedirects = false
        try {
            metadata.requestMethod = "DELETE"
            metadata.connectTimeout = 12_000
            metadata.readTimeout = 15_000
            metadata.setRequestProperty("apikey", key)
            metadata.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            val code = metadata.responseCode
            if (code !in 200..299) throw IOException(
                "Private file removed, but its record could not be cleared (HTTP $code). Retry deletion."
            )
        } finally {
            metadata.disconnect()
        }
    }

    /**
     * Downloads a private document with the current user's access token, then writes
     * it to a user-selected location. Never exposes a public or signed URL.
     * Buffer before writing so failed network requests do not create partial files.
     */
    suspend fun download(
        context: Context,
        scholarshipId: String,
        document: ApplicationDocumentItem,
        destination: Uri
    ) = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val userId = try { UUID.fromString(session.userId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
        val scholarship = try { UUID.fromString(scholarshipId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid scholarship identifier.") }
        val path = document.storagePath
        val prefix = "$userId/$scholarship/"
        if (!path.startsWith(prefix) || path.length <= prefix.length ||
            path.contains("..") || path.contains(92.toChar()) ||
            path.split('/').any { it.isBlank() }) {
            throw IOException("Document path does not belong to this application.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Document vault is not configured.")
        }
        val encodedPath = path.split('/').joinToString("/") {
            URLEncoder.encode(it, "UTF-8").replace("+", "%20")
        }
        val connection = URL("$base/storage/v1/object/authenticated/application-documents/$encodedPath")
            .openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        val maxBytes = 10 * 1024 * 1024
        val bytes = try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 25_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            val code = connection.responseCode
            if (code !in 200..299) throw IOException(
                when (code) {
                    401, 403 -> "Sign in again to download documents."
                    404 -> "This private file is no longer available."
                    else -> "Unable to download private file (HTTP $code)."
                }
            )
            if (connection.contentLengthLong > maxBytes) {
                throw IOException("The private file exceeds the 10 MB download limit.")
            }
            connection.inputStream.use { stream ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > maxBytes) {
                        throw IOException("The private file exceeds the 10 MB download limit.")
                    }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
        } finally {
            connection.disconnect()
        }
        if (bytes.isEmpty()) throw IOException("The private file is empty.")
        context.contentResolver.openOutputStream(destination, "w")?.use { it.write(bytes) }
            ?: throw IOException("Unable to write to the selected location.")
    }

    /**
     * Uploads one user-selected file to the existing private Supabase Storage bucket,
     * then creates its RLS-protected metadata row. No public URLs are created.
     */
    suspend fun upload(context: Context, scholarshipId: String, uri: Uri) = withContext(Dispatchers.IO) {
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

        val resolver = context.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }?.take(160)?.ifBlank { null } ?: "document"
        val extension = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
        val accepted = setOf("application/pdf", "image/jpeg", "image/png", "image/heic", "image/heif")
        val mime = resolver.getType(uri)?.lowercase(Locale.ROOT).takeIf { it in accepted }
            ?: when (extension) {
                "pdf" -> "application/pdf"
                "jpg", "jpeg" -> "image/jpeg"
                "png" -> "image/png"
                "heic" -> "image/heic"
                "heif" -> "image/heif"
                else -> null
            }
            ?: throw IOException("Choose a PDF, JPEG, PNG, HEIC or HEIF file.")

        // Never buffer an unlimited-size document, even if its provider reports no size.
        val maxBytes = 6 * 1024 * 1024
        val bytes = resolver.openInputStream(uri)?.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                if (output.size() + read > maxBytes) {
                    throw IOException("Choose a file smaller than 6 MB.")
                }
                output.write(buffer, 0, read)
            }
            output.toByteArray()
        } ?: throw IOException("Unable to read the selected document.")
        if (bytes.isEmpty()) throw IOException("The selected document is empty.")

        val safeName = name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(100)
            .ifBlank { "document" }
        val storagePath = "$userId/$scholarship/${UUID.randomUUID()}-$safeName"
        val storage = URL("$base/storage/v1/object/application-documents/$storagePath")
            .openConnection() as HttpURLConnection
        storage.instanceFollowRedirects = false
        try {
            storage.requestMethod = "POST"
            storage.connectTimeout = 12_000
            storage.readTimeout = 25_000
            storage.doOutput = true
            storage.setFixedLengthStreamingMode(bytes.size)
            storage.setRequestProperty("apikey", key)
            storage.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            storage.setRequestProperty("Content-Type", mime)
            storage.setRequestProperty("x-upsert", "false")
            storage.outputStream.use { it.write(bytes) }
            val code = storage.responseCode
            if (code !in 200..299) throw IOException(
                if (code == 401 || code == 403) "Sign in again to upload documents."
                else "Unable to upload document (HTTP $code)."
            )
        } finally {
            storage.disconnect()
        }

        try {
            val row = JSONObject()
                .put("user_id", userId)
                .put("scholarship_id", scholarship)
                .put("file_name", name)
                .put("storage_path", storagePath)
                .put("content_type", mime)
                .put("byte_size", bytes.size)
            val metadata = URL("$base/rest/v1/application_documents")
                .openConnection() as HttpURLConnection
            metadata.instanceFollowRedirects = false
            try {
                metadata.requestMethod = "POST"
                metadata.connectTimeout = 12_000
                metadata.readTimeout = 15_000
                metadata.doOutput = true
                metadata.setRequestProperty("apikey", key)
                metadata.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                metadata.setRequestProperty("Content-Type", "application/json")
                metadata.setRequestProperty("Prefer", "return=minimal")
                metadata.outputStream.use { it.write(row.toString().toByteArray(Charsets.UTF_8)) }
                val code = metadata.responseCode
                if (code !in 200..299) throw IOException(
                    if (code == 401 || code == 403) "Sign in again to save document metadata."
                    else "Unable to save document metadata (HTTP $code)."
                )
            } finally {
                metadata.disconnect()
            }
        } catch (failure: Exception) {
            // Match iOS rollback behavior when metadata creation fails.
            val cleanedUp = try {
                val cleanup = URL("$base/storage/v1/object/application-documents")
                    .openConnection() as HttpURLConnection
                cleanup.instanceFollowRedirects = false
                try {
                    cleanup.requestMethod = "DELETE"
                    cleanup.connectTimeout = 12_000
                    cleanup.readTimeout = 15_000
                    cleanup.doOutput = true
                    cleanup.setRequestProperty("apikey", key)
                    cleanup.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                    cleanup.setRequestProperty("Content-Type", "application/json")
                    val payload = JSONObject().put("prefixes", JSONArray().put(storagePath))
                    cleanup.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                    cleanup.responseCode in 200..299
                } finally {
                    cleanup.disconnect()
                }
            } catch (_: Exception) { false }
            if (!cleanedUp) {
                throw IOException("Document metadata could not be saved; private upload cleanup may be needed.", failure)
            }
            throw failure
        }
    }

}

/** Private document metadata and upload controls; no public document URLs. */
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
    var uploading by remember(userId, scholarshipId) { mutableStateOf(false) }
    var uploadSuccess by remember(userId, scholarshipId) { mutableStateOf(false) }
    var deleting by remember(userId, scholarshipId) { mutableStateOf(false) }
    var pendingDelete by remember(userId, scholarshipId) { mutableStateOf<ApplicationDocumentItem?>(null) }
    var downloading by remember(userId, scholarshipId) { mutableStateOf(false) }
    var downloadSuccess by remember(userId, scholarshipId) { mutableStateOf(false) }
    var pendingDownload by remember(userId, scholarshipId) { mutableStateOf<ApplicationDocumentItem?>(null) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val savePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream")
    ) { uri ->
        val document = pendingDownload
        pendingDownload = null
        if (uri != null && document != null && !downloading) {
            downloading = true
            downloadSuccess = false
            error = null
            scope.launch {
                try {
                    ApplicationDocumentsRepository.download(
                        context.applicationContext, scholarshipId, document, uri
                    )
                    downloadSuccess = true
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to download private document."
                } finally {
                    downloading = false
                }
            }
        }
    }
    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null && !uploading) {
            uploading = true
            uploadSuccess = false
            error = null
            scope.launch {
                try {
                    ApplicationDocumentsRepository.upload(context.applicationContext, scholarshipId, uri)
                    uploadSuccess = true
                    refresh++
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to upload document."
                } finally {
                    uploading = false
                }
            }
        }
    }

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
    OutlinedButton(
        enabled = !loading && !uploading && !deleting && !downloading,
        onClick = { filePicker.launch(arrayOf("application/pdf", "image/*")) }
    ) { Text(if (uploading) "Uploading…" else "Upload PDF or image (max 6 MB)") }
    if (uploading) CircularProgressIndicator(Modifier.size(24.dp))
    if (uploadSuccess) Text("Document uploaded.", color = MaterialTheme.colorScheme.primary)
    if (downloading) CircularProgressIndicator(Modifier.size(24.dp))
    if (downloadSuccess) Text("Document saved to selected location.", color = MaterialTheme.colorScheme.primary)
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
                    TextButton(
                        enabled = !uploading && !deleting && !loading && !downloading,
                        onClick = {
                            pendingDownload = doc
                            downloadSuccess = false
                            savePicker.launch(doc.fileName)
                        }
                    ) { Text("Download file") }
                    TextButton(
                        enabled = !uploading && !deleting && !loading && !downloading,
                        onClick = { pendingDelete = doc }
                    ) { Text("Delete file") }
                }
            }
        }
    }
    pendingDelete?.let { document ->
        AlertDialog(
            onDismissRequest = { if (!deleting) pendingDelete = null },
            title = { Text("Delete private document?") },
            text = { Text("Permanently delete ${document.fileName}? This cannot be undone.") },
            confirmButton = {
                TextButton(
                    enabled = !deleting && !uploading,
                    onClick = {
                        deleting = true
                        error = null
                        scope.launch {
                            try {
                                ApplicationDocumentsRepository.delete(scholarshipId, document)
                                pendingDelete = null
                                uploadSuccess = false
                                refresh++
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                error = failure.message ?: "Unable to delete document."
                                pendingDelete = null
                            } finally {
                                deleting = false
                            }
                        }
                    }
                ) { Text(if (deleting) "Deleting…" else "Delete") }
            },
            dismissButton = {
                TextButton(enabled = !deleting, onClick = { pendingDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }
    Text(
        "Preview: private document uploads and deletion. Download is not yet supported on Android.",
        style = MaterialTheme.typography.bodySmall
    )
}
