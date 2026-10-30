package com.grantly.android

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import java.io.IOException

/**
 * Read-only view of the current advisor's existing profile. The role and
 * approval status must both be verified before any professional details render.
 * Editing requires a separately reviewed, server-authorized update workflow.
 */
internal object AdvisorProfessionalProfileRules {
    fun canView(role: String, approvalStatus: String?): Boolean =
        role == "advisor" && approvalStatus == "approved"
}

@Composable
internal fun AdvisorProfessionalProfileContent(userId: String) {
    var profile by remember(userId) { mutableStateOf<AdvisorApplicationDraft?>(null) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }

    LaunchedEffect(userId, refresh) {
        loading = true
        profile = null
        error = null
        try {
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Sign in again.")
            }
            val role = StudentProfileRepository.load().role
            if (role != "advisor") {
                throw IOException("An approved advisor account is required.")
            }
            val existing = AdvisorApplicationRepository.load(userId)
            if (existing == null ||
                !AdvisorProfessionalProfileRules.canView(role, existing.approvalStatus)) {
                throw IOException("An approved professional profile is not available.")
            }
            if (AuthRepository.session?.userId == userId) profile = existing
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load your professional profile."
            }
        } finally {
            loading = false
        }
    }

    HorizontalDivider()
    Spacer(Modifier.height(12.dp))
    Text("Professional profile", style = MaterialTheme.typography.titleLarge)
    Text(
        "Review the approved information students may see in the advisor directory.",
        style = MaterialTheme.typography.bodySmall
    )
    Spacer(Modifier.height(12.dp))

    if (loading) {
        CircularProgressIndicator()
    } else if (error != null) {
        Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
    } else {
        profile?.let { current ->
            val fields = listOf(
                "Name" to current.displayName,
                "Professional title" to current.title,
                "Organization" to current.organization,
                "Years of experience" to current.yearsExperience,
                "Short biography" to current.shortBio,
                "Professional background" to current.bio,
                "Mentoring approach" to current.mentoringApproach,
                "Specialties" to current.specialties,
                "Countries" to current.countries,
                "Languages" to current.languages,
                "Introduction video" to current.introVideoUrl,
                "LinkedIn" to current.linkedinUrl,
                "Website" to current.websiteUrl
            )
            fields.filter { it.second.isNotBlank() }.forEach { (label, value) ->
                Text(label, fontWeight = FontWeight.SemiBold)
                Text(value, style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(8.dp))
            }
            if (current.avatarStoragePath != null || current.avatarUrl != null) {
                Text("Professional photo on file.", style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "This is a read-only preview. Editing an approved advisor profile is not yet available on Android.",
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
    Spacer(Modifier.height(10.dp))
    OutlinedButton(
        onClick = { refresh++ },
        enabled = !loading,
        modifier = Modifier.fillMaxWidth()
    ) { Text("Refresh professional profile") }
}
