package com.grantly.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
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

/** Advisor-only entry point, separate from the student's academic profile. */
internal data class AdvisorPortalCounts(
    val activeStudents: Int,
    val registrationRequests: Int,
    val openConsultations: Int
) {
    companion object {
        fun from(
            students: List<AdvisorStudentItem>,
            consultations: List<AdvisorIncomingConsultation>
        ) = AdvisorPortalCounts(
            activeStudents = AdvisorStudentRules.active(students),
            registrationRequests = AdvisorStudentRules.pending(students),
            openConsultations = consultations.count {
                AdvisorIncomingConsultationRules.isOpen(it.status)
            }
        )
    }
}

@Composable
internal fun AdvisorPortalContent(userId: String, onBack: () -> Unit, onOpenMessages: () -> Unit) {
    var section by remember(userId) { mutableStateOf("overview") }
    var counts by remember(userId) { mutableStateOf<AdvisorPortalCounts?>(null) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }

    BackHandler(enabled = section != "overview") { section = "overview" }

    LaunchedEffect(userId, section, refresh) {
        if (section != "overview") return@LaunchedEffect
        loading = true
        counts = null
        error = null
        try {
            if (AuthRepository.session?.userId != userId ||
                StudentProfileRepository.load().role != "advisor") {
                throw IOException("An approved advisor account is required.")
            }
            val students = AdvisorStudentsRepository.load(userId)
            val consultations = AdvisorIncomingConsultationsRepository.load(userId)
            if (AuthRepository.session?.userId == userId) {
                counts = AdvisorPortalCounts.from(students, consultations)
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load the advisor overview."
            }
        } finally {
            loading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedButton(onClick = onBack) { Text("Back to profile") }
        Text("Advisor Portal", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Manage student registrations and consultation requests.",
            style = MaterialTheme.typography.bodyMedium
        )
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf(
                "overview" to "Overview",
                "students" to "My students",
                "consultations" to "Consultations",
                "professional" to "Professional profile"
            ).forEach { (value, label) ->
                FilterChip(
                    selected = section == value,
                    onClick = { section = value },
                    label = { Text(label) }
                )
            }
        }
        // Keep the advisor inbox accessible even when overview loading fails.
        OutlinedButton(onClick = onOpenMessages, modifier = Modifier.fillMaxWidth()) {
            Text("Open Messages")
        }
        when (section) {
            "students" -> AdvisorStudentsContent(userId)
            "consultations" -> AdvisorIncomingConsultationsContent(userId)
            "professional" -> AdvisorProfessionalProfileContent(userId)
            else -> {
                if (loading) {
                    CircularProgressIndicator()
                } else if (error != null) {
                    Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
                    OutlinedButton(onClick = { refresh++ }) { Text("Retry overview") }
                } else {
                    val snapshot = counts
                    if (snapshot != null) {
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text("Overview", fontWeight = FontWeight.SemiBold)
                                Text("Active students: ${snapshot.activeStudents}")
                                Text("Registration requests: ${snapshot.registrationRequests}")
                                Text("Open consultations: ${snapshot.openConsultations}")
                            }
                        }
                    }
                    OutlinedButton(onClick = { section = "students" }, modifier = Modifier.fillMaxWidth()) {
                        Text("Manage students")
                    }
                    OutlinedButton(onClick = { section = "consultations" }, modifier = Modifier.fillMaxWidth()) {
                        Text("Review consultations")
                    }
                    OutlinedButton(onClick = { refresh++ }, modifier = Modifier.fillMaxWidth()) {
                        Text("Refresh overview")
                    }
                }
                Text(
                    "Messages opens the existing advisor inbox. Video calls and full iOS advisor navigation are not yet available in this Android preview.",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}
