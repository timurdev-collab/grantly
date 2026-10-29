package com.grantly.android

import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Uses the existing iOS advisor_profiles row, advisor-media storage bucket and
 * submit_advisor_application RPC. No new tables, policies or privileged keys.
 */
internal object AdvisorApplicationRepository {
    private fun config(): Pair<String, String> {
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor application service is not configured.")
        }
        return base to key
    }

    private fun connection(url: String, method: String, token: String, key: String) =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            instanceFollowRedirects = false
            connectTimeout = 12_000
            readTimeout = 20_000
            setRequestProperty("apikey", key)
            setRequestProperty("Authorization", "Bearer " + token)
            setRequestProperty("Accept", "application/json")
        }

    private fun ensureAccount(userId: String) {
        val current = AuthRepository.session?.userId
        if (current != userId) throw IOException("Your account changed. Sign in again.")
        try { UUID.fromString(userId) }
        catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
    }

    private fun JSONObject.valueOrEmpty(key: String): String =
        if (isNull(key)) "" else optString(key, "")

    private fun JSONObject.arrayText(key: String): String {
        val values = optJSONArray(key) ?: return ""
        return (0 until values.length()).map { values.optString(it) }
            .filter { it.isNotBlank() }.joinToString(", ")
    }

    suspend fun load(userId: String): AdvisorApplicationDraft? = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        ensureAccount(userId)
        val (base, key) = config()
        val request = connection(
            base + "/rest/v1/advisor_profiles?select=*&id=eq." + userId + "&limit=1",
            "GET", session.accessToken, key
        )
        try {
            val code = request.responseCode
            if (code !in 200..299) {
                throw IOException(if (code == 401 || code == 403)
                    "Advisor application access denied. Sign in again."
                else "Unable to load advisor application (HTTP " + code + ").")
            }
            val rows = JSONArray(request.inputStream.bufferedReader().use { it.readText() })
            val row = rows.optJSONObject(0) ?: return@withContext null
            AdvisorApplicationDraft(
                displayName = row.valueOrEmpty("display_name"),
                title = row.valueOrEmpty("title"),
                organization = row.valueOrEmpty("organization"),
                yearsExperience = row.valueOrEmpty("years_experience"),
                shortBio = row.valueOrEmpty("short_bio"),
                bio = row.valueOrEmpty("bio"),
                mentoringApproach = row.valueOrEmpty("mentoring_approach"),
                specialties = row.arrayText("specialties"),
                countries = row.arrayText("countries"),
                languages = row.arrayText("languages"),
                introVideoUrl = row.valueOrEmpty("intro_video_url"),
                linkedinUrl = row.valueOrEmpty("linkedin_url"),
                websiteUrl = row.valueOrEmpty("website_url"),
                avatarStoragePath = row.valueOrEmpty("avatar_storage_path").ifBlank { null },
                avatarUrl = row.valueOrEmpty("avatar_url").ifBlank { null },
                approvalStatus = row.valueOrEmpty("approval_status").ifBlank { null }
            )
        } finally { request.disconnect() }
    }

    suspend fun submit(userId: String, draft: AdvisorApplicationDraft, photo: ByteArray?) =
        withContext(Dispatchers.IO) {
            val issue = draft.completeIssue(photo != null)
            if (issue != null) throw IllegalArgumentException(issue)
            val session = AuthRepository.activeSession()
            ensureAccount(userId)
            val (base, key) = config()
            var avatarPath = draft.avatarStoragePath
            if (photo != null) {
                require(photo.isNotEmpty() && photo.size <= 5 * 1024 * 1024) {
                    "Please choose a smaller professional photo."
                }
                avatarPath = userId + "/avatar/" + UUID.randomUUID().toString() + ".jpg"
                val upload = connection(
                    base + "/storage/v1/object/advisor-media/" + avatarPath,
                    "POST", session.accessToken, key
                )
                try {
                    upload.doOutput = true
                    upload.setFixedLengthStreamingMode(photo.size)
                    upload.setRequestProperty("Content-Type", "image/jpeg")
                    upload.setRequestProperty("cache-control", "3600")
                    upload.setRequestProperty("x-upsert", "false")
                    upload.outputStream.use { it.write(photo) }
                    val code = upload.responseCode
                    if (code !in 200..299) {
                        throw IOException(if (code == 401 || code == 403)
                            "You do not have permission to upload an advisor photo."
                        else "Advisor photo upload failed (HTTP " + code + ").")
                    }
                } finally { upload.disconnect() }
            }

            // Do not submit the original account's application after a logout or switch.
            ensureAccount(userId)
            val params = JSONObject().apply {
                fun optional(value: String): Any =
                    value.trim().takeIf { it.isNotEmpty() } ?: JSONObject.NULL
                fun csv(values: String): JSONArray = JSONArray(draft.csv(values))
                put("p_display_name", draft.displayName.trim())
                put("p_title", optional(draft.title))
                put("p_organization", optional(draft.organization))
                put("p_short_bio", optional(draft.shortBio))
                put("p_bio", optional(draft.bio))
                put("p_mentoring_approach", optional(draft.mentoringApproach))
                put("p_years_experience", draft.experienceOrNull() ?: JSONObject.NULL)
                put("p_specialties", csv(draft.specialties))
                put("p_countries", csv(draft.countries))
                put("p_languages", csv(draft.languages))
                put("p_linkedin_url", optional(draft.linkedinUrl))
                put("p_website_url", optional(draft.websiteUrl))
                put("p_avatar_storage_path", avatarPath ?: JSONObject.NULL)
                put("p_intro_video_storage_path", JSONObject.NULL)
                put("p_intro_video_url", optional(draft.introVideoUrl))
            }
            val request = connection(
                base + "/rest/v1/rpc/submit_advisor_application",
                "POST", session.accessToken, key
            )
            try {
                request.doOutput = true
                request.setRequestProperty("Content-Type", "application/json")
                request.outputStream.use { it.write(params.toString().toByteArray(Charsets.UTF_8)) }
                val code = request.responseCode
                if (code !in 200..299) {
                    throw IOException(if (code == 401 || code == 403)
                        "Advisor application submission was denied. Please sign in again."
                    else "Advisor application was not submitted (HTTP " + code + ").")
                }
                request.inputStream.close()
            } finally { request.disconnect() }
        }
}

@Composable
internal fun AdvisorApplicationFormContent(
    userId: String,
    defaultName: String,
    onSubmitted: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var draft by remember(userId) {
        mutableStateOf(AdvisorApplicationDraft(displayName = defaultName))
    }
    var step by remember(userId) { mutableIntStateOf(0) }
    var photo by remember(userId) { mutableStateOf<ByteArray?>(null) }
    var loading by remember(userId) { mutableStateOf(true) }
    var loadFailed by remember(userId) { mutableStateOf(false) }
    var loadAttempt by remember(userId) { mutableIntStateOf(0) }
    var preparingPhoto by remember(userId) { mutableStateOf(false) }
    var submitting by remember(userId) { mutableStateOf(false) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    val busy = loading || preparingPhoto || submitting
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null && !busy) {
            preparingPhoto = true
            error = null
            scope.launch {
                try {
                    val prepared = ProfileAvatarRepository.prepareAdvisorJpeg(context, uri)
                    if (AuthRepository.session?.userId == userId) photo = prepared
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to read the selected photo."
                } finally { preparingPhoto = false }
            }
        }
    }
    LaunchedEffect(userId, loadAttempt) {
        loading = true
        loadFailed = false
        error = null
        try {
            val existing = AdvisorApplicationRepository.load(userId)
            if (AuthRepository.session?.userId == userId) {
                draft = existing ?: AdvisorApplicationDraft(displayName = defaultName)
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            loadFailed = true
            error = failure.message ?: "Unable to load your advisor application."
        } finally { loading = false }
    }

    val green = Color(0xFF123E30)
    val steps = listOf("Professional profile", "How you can help", "Introduction & review")
    HorizontalDivider()
    Spacer(Modifier.height(14.dp))
    Text("Advisor application", style = MaterialTheme.typography.titleLarge, color = green)
    Spacer(Modifier.height(6.dp))
    Text("Step " + (step + 1) + " of 3 · " + steps[step],
        style = MaterialTheme.typography.titleSmall)
    Spacer(Modifier.height(12.dp))
    if (loading) {
        CircularProgressIndicator(color = green)
        return
    }
    if (error != null) {
        Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
        Spacer(Modifier.height(12.dp))
    }
    if (loadFailed) {
        // A failed read must not silently turn an existing application into a blank
        // draft that the user can accidentally submit over their saved details.
        Text("Your saved application could not be loaded. Editing is disabled until it can be retrieved.",
            style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.height(10.dp))
        OutlinedButton(onClick = { loadAttempt++ }) { Text("Retry loading application") }
        return
    }

    if (!draft.isApplicationResubmittable()) {
        Text(
            "This advisor profile has status: " + draft.approvalStatus +
                ". Applications in this status cannot be resubmitted. Approved and suspended advisors need a separate profile editor.",
            style = MaterialTheme.typography.bodyMedium
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Editing an approved advisor profile is not yet available in this Android preview.",
            style = MaterialTheme.typography.bodySmall
        )
        return
    }

    @Composable
    fun field(label: String, value: String, multiline: Boolean = false,
              keyboard: KeyboardType = KeyboardType.Text, onChange: (String) -> Unit) {
        OutlinedTextField(
            value = value, onValueChange = { onChange(it); error = null },
            label = { Text(label) },
            singleLine = !multiline,
            minLines = if (multiline) 3 else 1,
            keyboardOptions = KeyboardOptions(keyboardType = keyboard),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp)
        )
        Spacer(Modifier.height(10.dp))
    }

    when (step) {
        0 -> {
            field("Full name", draft.displayName) { draft = draft.copy(displayName = it) }
            field("Professional title", draft.title) { draft = draft.copy(title = it) }
            field("Organization (optional)", draft.organization) {
                draft = draft.copy(organization = it)
            }
            field("Years of relevant experience", draft.yearsExperience,
                keyboard = KeyboardType.Number) { draft = draft.copy(yearsExperience = it) }
            val bitmap = remember(photo) {
                photo?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
            }
            if (bitmap != null) {
                Image(bitmap.asImageBitmap(), contentDescription = "Selected advisor photo",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(84.dp).clip(CircleShape))
            }
            if ((draft.avatarStoragePath != null || draft.avatarUrl != null) && photo == null) {
                Text("Existing professional photo on file.",
                    style = MaterialTheme.typography.bodySmall)
            }
            OutlinedButton(enabled = !busy, onClick = { photoPicker.launch("image/*") }) {
                Text(if (preparingPhoto) "Preparing photo…" else "Choose professional photo")
            }
            Text("Professional headshot · JPG, PNG or supported HEIC · max 5 MB after resizing",
                style = MaterialTheme.typography.bodySmall)
        }
        1 -> {
            field("Short biography (optional)", draft.shortBio, multiline = true) {
                draft = draft.copy(shortBio = it)
            }
            field("Professional background (at least 80 characters)", draft.bio, multiline = true) {
                draft = draft.copy(bio = it)
            }
            field("Mentoring approach (optional)", draft.mentoringApproach, multiline = true) {
                draft = draft.copy(mentoringApproach = it)
            }
            field("Specialties (comma separated)", draft.specialties) {
                draft = draft.copy(specialties = it)
            }
            field("Countries (comma separated, optional)", draft.countries) {
                draft = draft.copy(countries = it)
            }
            field("Languages (comma separated)", draft.languages) {
                draft = draft.copy(languages = it)
            }
        }
        else -> {
            field("HTTPS introduction video URL", draft.introVideoUrl,
                keyboard = KeyboardType.Uri) { draft = draft.copy(introVideoUrl = it) }
            Text("Add a short video link from YouTube, Vimeo, Loom or another HTTPS source.",
                style = MaterialTheme.typography.bodySmall)
            field("LinkedIn URL (optional)", draft.linkedinUrl, keyboard = KeyboardType.Uri) {
                draft = draft.copy(linkedinUrl = it)
            }
            field("Website URL (optional)", draft.websiteUrl, keyboard = KeyboardType.Uri) {
                draft = draft.copy(websiteUrl = it)
            }
            HorizontalDivider()
            Spacer(Modifier.height(10.dp))
            Text("Review", fontWeight = FontWeight.SemiBold)
            Text("Name: " + draft.displayName.trim())
            Text("Title: " + draft.title.trim())
            Text("Experience: " + (draft.yearsExperience.ifBlank { "Not specified" }))
            Text("Specialties: " + draft.csv(draft.specialties).joinToString(" · "))
            Text("Languages: " + draft.csv(draft.languages).joinToString(" · "))
            Text("Applications are reviewed by an administrator before appearing to students.",
                style = MaterialTheme.typography.bodySmall)
        }
    }
    Spacer(Modifier.height(16.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (step > 0) {
            OutlinedButton(enabled = !busy, onClick = { step--; error = null }) {
                Text("Back")
            }
        }
        Button(enabled = !busy, onClick = {
            if (step < 2) {
                val issue = draft.validationIssue(step, photo != null)
                if (issue != null) error = issue else { step++; error = null }
            } else {
                val issue = draft.completeIssue(photo != null)
                if (issue != null) {
                    error = issue
                } else {
                    submitting = true
                    error = null
                    scope.launch {
                        try {
                            AdvisorApplicationRepository.submit(userId, draft, photo)
                            if (AuthRepository.session?.userId == userId) onSubmitted()
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Unable to submit your application."
                        } finally { submitting = false }
                    }
                }
            }
        }, colors = ButtonDefaults.buttonColors(containerColor = green)) {
            Text(if (submitting) "Submitting…" else if (step == 2) "Submit for review" else "Continue")
        }
    }
    Spacer(Modifier.height(16.dp))
}
