package com.grantly.android

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Tokens remain in memory; persistence is deferred until Android Keystore storage is available. */
internal data class AuthSession(
    val userId: String,
    val email: String,
    val accessToken: String,
    val refreshToken: String,
    val expiresAtMs: Long
)

internal object AuthRepository {
    var session by mutableStateOf<AuthSession?>(null)
        private set
    private val refreshMutex = Mutex()

    private fun baseUrl(): String {
        val url = BuildConfig.SUPABASE_URL.trimEnd('/')
        if (!url.startsWith("https://") || BuildConfig.SUPABASE_PUBLISHABLE_KEY.isBlank()) {
            throw IOException("Sign-in service is not configured.")
        }
        return url
    }

    private fun post(path: String, body: JSONObject, bearer: String? = null): JSONObject {
        val connection = URL(baseUrl() + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", BuildConfig.SUPABASE_PUBLISHABLE_KEY)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            if (bearer != null) connection.setRequestProperty("Authorization", "Bearer $bearer")
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                val message = when (status) {
                    400, 401 -> if (path.contains("grant_type=refresh_token"))
                        "Session expired. Please sign in again."
                    else "Check your email and password, and confirm your email if required."
                    422 -> "Check the email address and password requirements."
                    429 -> "Too many attempts. Please wait before trying again."
                    else -> "Account service unavailable (HTTP $status)."
                }
                throw IOException(message)
            }
            if (status == 204) return JSONObject()
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            return if (response.isBlank()) JSONObject() else JSONObject(response)
        } finally {
            connection.disconnect()
        }
    }

    suspend fun signIn(email: String, password: String) {
        val normalized = email.trim().lowercase()
        require(normalized.contains('@') && normalized.length <= 254) { "Enter a valid email address." }
        require(password.isNotEmpty()) { "Enter your password." }
        val result = withContext(Dispatchers.IO) {
            post("/auth/v1/token?grant_type=password", JSONObject().apply {
                put("email", normalized)
                put("password", password)
            })
        }
        val token = result.optString("access_token")
        val user = result.optJSONObject("user")
        val userId = user?.optString("id").orEmpty()
        if (token.isBlank() || userId.isBlank()) throw IOException("Unable to verify your session.")
        val refreshToken = result.optString("refresh_token")
        val expiresIn = result.optLong("expires_in", 0L)
        if (refreshToken.isBlank() || expiresIn <= 0L) throw IOException("Unable to verify your session.")
        session = AuthSession(
            userId, user?.optString("email").orEmpty().ifBlank { normalized },
            token, refreshToken, System.currentTimeMillis() + expiresIn * 1000L
        )
    }

    /**
     * Refresh an expiring access token before authenticated API requests.
     * A mutex prevents concurrent requests from consuming the same rotating refresh token.
     * Network errors leave the in-memory session intact so the user can retry.
     */
    suspend fun activeSession(): AuthSession = refreshMutex.withLock {
        val current = session ?: throw IOException("Sign in to continue.")
        if (current.expiresAtMs - System.currentTimeMillis() > 60_000L) {
            return@withLock current
        }
        val result = try {
            withContext(Dispatchers.IO) {
                post("/auth/v1/token?grant_type=refresh_token",
                    JSONObject().put("refresh_token", current.refreshToken))
            }
        } catch (failure: IOException) {
            if (failure.message == "Session expired. Please sign in again." && session === current) {
                session = null
            }
            throw failure
        }
        if (session !== current) throw IOException("Your account changed. Please retry.")
        val token = result.optString("access_token")
        val refreshToken = result.optString("refresh_token")
        val expiresIn = result.optLong("expires_in", 0L)
        val returnedUserId = result.optJSONObject("user")?.optString("id").orEmpty()
        if (token.isBlank() || refreshToken.isBlank() || expiresIn <= 0L ||
            (returnedUserId.isNotBlank() && returnedUserId != current.userId)) {
            session = null
            throw IOException("Session could not be refreshed. Please sign in again.")
        }
        AuthSession(
            current.userId, current.email, token, refreshToken,
            System.currentTimeMillis() + expiresIn * 1000L
        ).also { session = it }
    }

    suspend fun signUp(email: String, password: String) {
        val normalized = email.trim().lowercase()
        require(normalized.contains('@') && normalized.length <= 254) { "Enter a valid email address." }
        require(password.length in 8..128) { "Use a password between 8 and 128 characters." }
        withContext(Dispatchers.IO) {
            post("/auth/v1/signup", JSONObject().apply {
                put("email", normalized)
                put("password", password)
            })
        }
        // A confirmation email may be required. Never assume signup is an authenticated session.
    }

    suspend fun signOut() {
        val token = session?.accessToken
        session = null
        if (token != null) {
            // Clear local access immediately even if remote sign-out cannot be reached.
            try {
                withContext(Dispatchers.IO) { post("/auth/v1/logout", JSONObject(), token) }
            } catch (_: IOException) {
                // No persistent token exists in this preview.
            }
        }
    }
}
