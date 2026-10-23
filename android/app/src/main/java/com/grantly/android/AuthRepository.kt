package com.grantly.android

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** A deliberately memory-only session until secure persistence and refresh are implemented. */
internal data class AuthSession(val userId: String, val email: String, val accessToken: String)

internal object AuthRepository {
    var session by mutableStateOf<AuthSession?>(null)
        private set

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
                    400, 401 -> "Check your email and password, and confirm your email if required."
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
        session = AuthSession(userId, user?.optString("email").orEmpty().ifBlank { normalized }, token)
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
