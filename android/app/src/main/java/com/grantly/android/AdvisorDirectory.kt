package com.grantly.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Publicly listed, approved advisors only. Consultations and messaging are not yet supported. */
internal data class AdvisorDirectoryItem(
    val id: String,
    val name: String,
    val title: String,
    val organization: String,
    val summary: String,
    val bio: String,
    val specialties: List<String>,
    val countries: List<String>,
    val languages: List<String>,
    val featured: Boolean
)

internal object AdvisorDirectoryRepository {
    private fun JSONObject.text(key: String): String =
        if (isNull(key)) "" else optString(key, "")

    private fun JSONObject.textArray(key: String): List<String> {
        val values = optJSONArray(key) ?: return emptyList()
        return (0 until values.length()).mapNotNull { i ->
            values.optString(i).trim().takeIf { it.isNotEmpty() }
        }
    }

    suspend fun list(): List<AdvisorDirectoryItem> = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor directory is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/available_advisors")
            .openConnection() as HttpURLConnection
        try {
            // Never forward an authenticated advisor-directory request to a redirected host.
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write("{}".toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403) "Sign in again to browse advisors."
                    else "Advisor directory unavailable (HTTP $status)."
                )
            }
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val rows = JSONArray(response)
            buildList {
                for (index in 0 until rows.length()) {
                    val row = rows.optJSONObject(index) ?: continue
                    val id = row.text("id")
                    if (id.isBlank()) continue
                    add(AdvisorDirectoryItem(
                        id = id,
                        name = row.text("display_name").ifBlank { "EduT advisor" },
                        title = row.text("title"),
                        organization = row.text("organization"),
                        summary = row.text("short_bio"),
                        bio = row.text("bio"),
                        specialties = row.textArray("specialties"),
                        countries = row.textArray("countries"),
                        languages = row.textArray("languages"),
                        featured = row.optBoolean("is_featured", false)
                    ))
                }
            }
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun AdvisorDirectoryContent(onBack: () -> Unit) {
    val userId = AuthRepository.session?.userId
    var advisors by remember(userId) { mutableStateOf<List<AdvisorDirectoryItem>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(userId != null) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var query by remember { mutableStateOf("") }
    var selected by remember(userId) { mutableStateOf<AdvisorDirectoryItem?>(null) }
    var showingRequests by remember(userId) { mutableStateOf(false) }
    var showingBooking by remember(userId) { mutableStateOf(false) }
    var chatId by remember(userId) { mutableStateOf<String?>(null) }
    var openingChat by remember(userId) { mutableStateOf(false) }
    var chatError by remember(userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val forest = Color(0xFF123E30)

    LaunchedEffect(userId, refresh) {
        if (userId == null) return@LaunchedEffect
        loading = true
        error = null
        try {
            val result = AdvisorDirectoryRepository.list()
            if (AuthRepository.session?.userId == userId) advisors = result
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load advisors."
            }
        } finally {
            loading = false
        }
    }

    // Handle system Back within the advisor navigation stack. The parent screen
    // handles Back from the directory root; nested views return one level at a time.
    val navigateBack: () -> Unit = {
        when {
            showingRequests -> showingRequests = false
            chatId != null -> chatId = null
            showingBooking -> showingBooking = false
            selected != null -> selected = null
            else -> onBack()
        }
    }
    BackHandler(enabled = showingRequests || chatId != null || showingBooking || selected != null) {
        navigateBack()
    }
    TextButton(onClick = navigateBack) {
        Text(if (selected == null && !showingRequests) "← Home" else if (showingBooking || chatId != null) "← Advisor profile" else "← All advisors")
    }
    Spacer(Modifier.height(8.dp))
    Text(if (showingRequests) "My consultations" else if (chatId != null) "Advisor messages" else if (showingBooking) "Advisor booking" else if (selected == null) "Find an advisor" else selected!!.name,
        style = MaterialTheme.typography.headlineMedium, color = forest)
    Spacer(Modifier.height(8.dp))
    Text("Verified educational advisors · directory preview",
        style = MaterialTheme.typography.bodyMedium)
    Spacer(Modifier.height(16.dp))

    if (userId == null) {
        Text("Sign in from Profile to view approved advisors.")
        return
    }
    if (showingRequests) {
        AdvisorConsultationHistoryContent()
        return
    }
    if (loading) {
        CircularProgressIndicator()
        return
    }
    if (error != null) {
        Text(error ?: "", color = MaterialTheme.colorScheme.error)
        OutlinedButton(onClick = { refresh++ }) { Text("Try again") }
        return
    }
    if (selected != null) {
        val advisor = selected!!
        if (chatId != null) {
            AdvisorMessageThreadContent(chatId!!, advisor.name, advisor.id)
            return
        }
        if (showingBooking) {
            AdvisorBookingContent(advisor, onViewRequests = {
                showingBooking = false
                showingRequests = true
            })
            return
        }
        AdvisorLine("Title", advisor.title)
        AdvisorLine("Organization", advisor.organization)
        AdvisorLine("About", advisor.bio.ifBlank { advisor.summary })
        AdvisorLine("Expertise", advisor.specialties.joinToString(", "))
        AdvisorLine("Countries", advisor.countries.joinToString(", "))
        AdvisorLine("Languages", advisor.languages.joinToString(", "))
        Spacer(Modifier.height(18.dp))
        AdvisorServicesContent(advisor.id)
        Button(onClick = { showingBooking = true }) { Text("Book a consultation") }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = {
            openingChat = true
            chatError = null
            scope.launch {
                try {
                    val id = AdvisorMessagesRepository.startAdvisorChat(advisor.id)
                    if (AuthRepository.session?.userId == userId) chatId = id
                } catch (failure: Exception) {
                    chatError = failure.message ?: "Unable to open advisor conversation."
                } finally {
                    openingChat = false
                }
            }
        }, enabled = !openingChat) { Text(if (openingChat) "Opening conversation…" else "Message advisor") }
        if (chatError != null) Text(chatError.orEmpty(), color = MaterialTheme.colorScheme.error)
        Text("Booking requests require separate payment confirmation. Advisor messages are restricted by server access rules.",
            style = MaterialTheme.typography.bodySmall)
        return
    }

    OutlinedButton(onClick = { showingRequests = true }) {
        Text("My consultation requests")
    }
    Spacer(Modifier.height(10.dp))
    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        label = { Text("Search advisors, expertise, countries") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(14.dp))
    val matches = advisors.filter { advisor ->
        val haystack = listOf(advisor.name, advisor.title, advisor.organization, advisor.summary)
            .plus(advisor.specialties).plus(advisor.countries).joinToString(" ")
        haystack.contains(query.trim(), ignoreCase = true)
    }
    if (matches.isEmpty()) {
        Text(if (query.isBlank()) "No approved advisors are available yet." else "No advisors match your search.")
    }
    matches.forEach { advisor ->
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)
                .clickable { selected = advisor },
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(Modifier.padding(16.dp)) {
                Text(advisor.name, fontWeight = FontWeight.Bold, color = forest)
                if (advisor.featured) Text("Featured advisor", style = MaterialTheme.typography.labelSmall)
                AdvisorLine("Title", advisor.title)
                AdvisorLine("Organization", advisor.organization)
                AdvisorLine("Expertise", advisor.specialties.take(3).joinToString(", "))
                if (advisor.summary.isNotBlank()) Text(advisor.summary, maxLines = 3)
                Spacer(Modifier.height(6.dp))
                Text("View profile →", color = forest, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
private fun AdvisorLine(label: String, value: String) {
    if (value.isNotBlank()) {
        Text("$label: $value", style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(bottom = 6.dp))
    }
}
