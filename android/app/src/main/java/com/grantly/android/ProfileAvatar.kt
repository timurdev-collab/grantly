package com.grantly.android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

/**
 * Uses the same existing avatars bucket and community_profiles.avatar_url as iOS.
 * No new schema, elevated credential, or storage policy is required.
 */
internal object ProfileAvatarRepository {
    private const val maxSourceBytes = 12 * 1024 * 1024
    private const val maxUploadBytes = 5 * 1024 * 1024

    private fun config(): Pair<String, String> {
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Profile photo service is not configured.")
        }
        return base to key
    }

    private fun accountId(expectedUserId: String): String {
        val id = try { UUID.fromString(expectedUserId).toString() }
        catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
        if (AuthRepository.session?.userId != expectedUserId) {
            throw IOException("Your account changed. Sign in again.")
        }
        return id
    }

    private fun connection(url: String, method: String, token: String, key: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            instanceFollowRedirects = false
            connectTimeout = 12_000
            readTimeout = 20_000
            setRequestProperty("apikey", key)
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
        }

    private fun boundedBytes(context: Context, uri: Uri): ByteArray {
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IOException("Could not open that photo.")
        return input.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                if (output.size() + count > maxSourceBytes) {
                    throw IOException("Choose a photo smaller than 12 MB.")
                }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
    }

    private fun resizedJpeg(raw: ByteArray): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
        if (bounds.outWidth !in 1..12_000 || bounds.outHeight !in 1..12_000 ||
            bounds.outWidth.toLong() * bounds.outHeight > 50_000_000L) {
            throw IOException("Choose a valid JPG, PNG or supported HEIC photo.")
        }
        var sample = 1
        while (bounds.outWidth / sample > 1200 || bounds.outHeight / sample > 1200) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = BitmapFactory.decodeByteArray(raw, 0, raw.size, options)
            ?: throw IOException("Could not decode that photo.")
        val scale = minOf(1f, 1200f / maxOf(decoded.width, decoded.height))
        val resized = if (scale < 1f) {
            Bitmap.createScaledBitmap(decoded, (decoded.width * scale).toInt().coerceAtLeast(1),
                (decoded.height * scale).toInt().coerceAtLeast(1), true)
        } else decoded
        val output = ByteArrayOutputStream()
        try {
            if (!resized.compress(Bitmap.CompressFormat.JPEG, 82, output)) {
                throw IOException("Could not convert that photo.")
            }
        } finally {
            if (resized !== decoded) resized.recycle()
            decoded.recycle()
        }
        return output.toByteArray().also {
            if (it.isEmpty() || it.size > maxUploadBytes) {
                throw IOException("Please choose a smaller photo (maximum 5 MB after resizing).")
            }
        }
    }

    suspend fun load(userId: String): Bitmap? = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val id = accountId(userId)
        val (base, key) = config()
        val request = connection(
            "$base/rest/v1/community_profiles?select=avatar_url&id=eq.$id&limit=1",
            "GET", session.accessToken, key
        )
        val avatarUrl = try {
            if (request.responseCode !in 200..299) return@withContext null
            val rows = JSONArray(request.inputStream.bufferedReader().use { it.readText() })
            rows.optJSONObject(0)?.optString("avatar_url")?.takeIf { it.isNotBlank() }
        } finally { request.disconnect() }
        // Do not download arbitrary URLs from a user-editable database field.
        val expected = "$base/storage/v1/object/public/avatars/$id/profile.jpg"
        if (avatarUrl != expected) return@withContext null
        val photo = (URL(expected).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = false
            connectTimeout = 12_000
            readTimeout = 20_000
        }
        try {
            if (photo.responseCode !in 200..299) return@withContext null
            val bytes = photo.inputStream.use { stream ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val n = stream.read(buffer)
                    if (n < 0) break
                    if (out.size() + n > maxUploadBytes) return@withContext null
                    out.write(buffer, 0, n)
                }
                out.toByteArray()
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth !in 1..12_000 || bounds.outHeight !in 1..12_000 ||
                bounds.outWidth.toLong() * bounds.outHeight > 50_000_000L) return@withContext null
            var sample = 1
            while (bounds.outWidth / sample > 1200 || bounds.outHeight / sample > 1200) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sample })
        } finally { photo.disconnect() }
    }

    suspend fun upload(context: Context, uri: Uri, userId: String): Bitmap = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val id = accountId(userId)
        val (base, key) = config()
        val bytes = resizedJpeg(boundedBytes(context, uri))
        val storage = connection("$base/storage/v1/object/avatars/$id/profile.jpg",
            "POST", session.accessToken, key)
        try {
            storage.doOutput = true
            storage.setFixedLengthStreamingMode(bytes.size)
            storage.setRequestProperty("Content-Type", "image/jpeg")
            storage.setRequestProperty("x-upsert", "true")
            storage.setRequestProperty("cache-control", "3600")
            storage.outputStream.use { it.write(bytes) }
            val status = storage.responseCode
            if (status !in 200..299) {
                throw IOException(if (status == 401 || status == 403)
                    "You do not have permission to update this photo."
                else "Profile photo upload failed (HTTP $status).")
            }
        } finally { storage.disconnect() }

        // Match the existing iOS implementation: the community profile owns the avatar URL.
        val update = connection("$base/rest/v1/community_profiles?id=eq.$id",
            "PATCH", session.accessToken, key)
        try {
            update.doOutput = true
            update.setRequestProperty("Content-Type", "application/json")
            update.setRequestProperty("Prefer", "return=representation")
            val payload = JSONObject()
                .put("avatar_url", "$base/storage/v1/object/public/avatars/$id/profile.jpg")
                .put("updated_at", Instant.now().toString())
            update.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val status = update.responseCode
            if (status !in 200..299) {
                throw IOException("Photo uploaded but profile update failed (HTTP $status). Retry the photo.")
            }
            val rows = JSONArray(update.inputStream.bufferedReader().use { it.readText() })
            if (rows.length() != 1) {
                throw IOException("Photo uploaded but the profile was not updated. Please try again.")
            }
        } finally { update.disconnect() }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IOException("Photo saved, but its preview could not be displayed.")
    }
}

@Composable
internal fun ProfileAvatarContent(userId: String, fullName: String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var photo by remember(userId) { mutableStateOf<Bitmap?>(null) }
    var uploading by remember(userId) { mutableStateOf(false) }
    var status by remember(userId) { mutableStateOf<String?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null && !uploading) {
            uploading = true
            status = null
            scope.launch {
                try {
                    val updated = ProfileAvatarRepository.upload(context, uri, userId)
                    if (AuthRepository.session?.userId == userId) {
                        photo = updated
                        status = "Profile photo updated."
                    }
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    status = failure.message ?: "Unable to update your photo."
                } finally { uploading = false }
            }
        }
    }
    LaunchedEffect(userId) {
        try {
            photo = ProfileAvatarRepository.load(userId)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            // The academic profile remains usable when its public photo cannot load.
        }
    }
    val parts = fullName.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    val initials = if (parts.size > 1) {
        (parts[0].take(1) + parts[1].take(1)).uppercase()
    } else parts.firstOrNull()?.take(2)?.uppercase() ?: "E"
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier.fillMaxWidth()) {
        Surface(shape = CircleShape, color = Color(0xFFE4ECDD),
            modifier = Modifier.size(72.dp)) {
            if (photo != null) {
                Image(bitmap = photo!!.asImageBitmap(), contentDescription = "Your profile photo",
                    contentScale = ContentScale.Crop, modifier = Modifier.clip(CircleShape))
            } else {
                Box(contentAlignment = androidx.compose.ui.Alignment.Center) {
                    Text(initials, fontWeight = FontWeight.Bold, color = Color(0xFF123E30))
                }
            }
        }
        Column {
            Text("Profile photo", fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(4.dp))
            OutlinedButton(enabled = !uploading, onClick = { picker.launch("image/*") }) {
                Text(if (uploading) "Uploading…" else "Choose photo")
            }
            Text("JPG, PNG or supported HEIC · up to 5 MB after resizing",
                style = MaterialTheme.typography.bodySmall)
        }
    }
    if (status != null) {
        Spacer(Modifier.height(6.dp))
        Text(status ?: "", color = if (status == "Profile photo updated.")
            Color(0xFF123E30) else MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodySmall)
    }
    Spacer(Modifier.height(14.dp))
}
