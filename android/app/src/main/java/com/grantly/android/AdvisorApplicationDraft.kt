package com.grantly.android

import java.net.URI
import java.net.URISyntaxException

/**
 * iOS advisor application steps, kept independent of Compose and networking so
 * validation is testable without uploading photos or changing server data.
 */
internal data class AdvisorApplicationDraft(
    val displayName: String = "",
    val title: String = "",
    val organization: String = "",
    val yearsExperience: String = "",
    val shortBio: String = "",
    val bio: String = "",
    val mentoringApproach: String = "",
    val specialties: String = "",
    val countries: String = "",
    val languages: String = "",
    val introVideoUrl: String = "",
    val linkedinUrl: String = "",
    val websiteUrl: String = "",
    val avatarStoragePath: String? = null,
    val avatarUrl: String? = null
) {
    fun csv(value: String): List<String> =
        value.split(',').map { it.trim() }.filter { it.isNotEmpty() }

    fun validationIssue(step: Int, hasPhoto: Boolean): String? = when (step) {
        0 -> when {
            displayName.isBlank() -> "Please enter your full name."
            title.isBlank() -> "Please enter your professional title."
            !hasPhoto && avatarStoragePath.isNullOrBlank() && avatarUrl.isNullOrBlank() ->
                "Please add a professional profile photo."
            yearsExperience.isNotBlank() &&
                (yearsExperience.trim().toIntOrNull()?.let { it in 0..80 } != true) ->
                "Please check your years of experience."
            else -> null
        }
        1 -> when {
            bio.trim().length < 80 ->
                "Please add a little more detail to your professional background."
            csv(specialties).isEmpty() -> "Please add at least one specialty."
            csv(languages).isEmpty() -> "Please add at least one language."
            else -> null
        }
        2 -> when {
            !isHttpsUrl(introVideoUrl) ->
                "Please add a valid HTTPS introduction video link."
            linkedinUrl.isNotBlank() && !isHttpsUrl(linkedinUrl) ->
                "Please check your LinkedIn URL."
            websiteUrl.isNotBlank() && !isHttpsUrl(websiteUrl) ->
                "Please check your website URL."
            else -> null
        }
        else -> "Invalid application step."
    }

    fun completeIssue(hasPhoto: Boolean): String? =
        (0..2).firstNotNullOfOrNull { validationIssue(it, hasPhoto) }

    fun experienceOrNull(): Int? = yearsExperience.trim().toIntOrNull()

    companion object {
        fun isHttpsUrl(value: String): Boolean = try {
            val uri = URI(value.trim())
            uri.scheme.equals("https", ignoreCase = true) &&
                !uri.host.isNullOrBlank() && uri.userInfo == null
        } catch (_: URISyntaxException) {
            // java.net.URI throws this checked exception for malformed input.
            false
        }
    }
}
