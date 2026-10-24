package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Like/unlike visible Community posts using the existing social_post_likes RLS policies.
 * Only the signed-in user's likes are fetched; this avoids loading other users' IDs.
 */
internal object CommunityLikesRepository {
    private fun validId(value: String): String = try {
        UUID.fromString(value).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid community identifier.")
    }

    private suspend fun request(
        path: String,
        method: String = "GET",
        payload: JSONObject? = null
    ): String {
        val session = AuthRepository.activeSession()
        return withContext(Dispatchers.IO) {
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Community service is not configured.")
            }
            val connection = URL(base + path).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                connection.setRequestProperty("Accept", "application/json")
                if (payload != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Prefer", "return=minimal")
                    connection.outputStream.use {
                        it.write(payload.toString().toByteArray(Charsets.UTF_8))
                    }
                }
                val status = connection.responseCode
                // Another device may have liked this post since the last refresh.
                if (method == "POST" && status == 409) return@withContext ""
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401, 403 -> "You cannot like this post. Sign in again or check Community access."
                        429 -> "Too many requests. Please try again shortly."
                        else -> "Community like request failed (HTTP $status)."
                    })
                }
                if (status == 204) "" else {
                    connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                }
            } finally {
                connection.disconnect()
            }
        }
    }

    suspend fun loadMine(postIds: List<String>): Set<String> {
        if (postIds.isEmpty()) return emptySet()
        require(postIds.size <= 50) { "Too many Community posts." }
        val ids = postIds.map(::validId).distinct()
        val userId = validId(AuthRepository.activeSession().userId)
        val rows = JSONArray(request(
            "/rest/v1/social_post_likes?select=post_id" +
                "&user_id=eq.$userId&post_id=in.(" + ids.joinToString(",") + ")" +
                "&limit=50"
        ))
        return buildSet {
            for (index in 0 until rows.length()) {
                val id = rows.optJSONObject(index)?.optString("post_id").orEmpty()
                if (id in ids) add(id)
            }
        }
    }

    suspend fun setLiked(postId: String, liked: Boolean) {
        val id = validId(postId)
        val userId = validId(AuthRepository.activeSession().userId)
        if (liked) {
            request(
                "/rest/v1/social_post_likes",
                "POST",
                JSONObject().put("post_id", id).put("user_id", userId)
            )
        } else {
            request(
                "/rest/v1/social_post_likes?post_id=eq.$id&user_id=eq.$userId",
                "DELETE"
            )
        }
    }
}
