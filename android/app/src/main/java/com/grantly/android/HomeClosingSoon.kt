package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

/**
 * Mirrors the iOS Home closing-soon urgency wording without treating rolling,
 * malformed or missing deadlines as calendar dates.
 */
internal object HomeDeadlineRules {
    /** iOS Home only features scholarships with verified status. */
    fun isVerified(status: String?): Boolean = status == "verified"

    fun parseDate(value: String?): LocalDate? {
        val raw = value?.trim() ?: return null
        if (raw.length < 10 || (raw.length > 10 && raw[10] != 'T' && raw[10] != ' ')) return null
        return try {
            LocalDate.parse(raw.substring(0, 10))
        } catch (_: DateTimeParseException) {
            null
        }
    }

    /** Shared Home hero and Closing soon policy: never promote unverified or expired listings. */
    fun eligibleUpcomingDate(status: String?, deadline: String?, today: LocalDate): LocalDate? {
        if (!isVerified(status)) return null
        return parseDate(deadline)?.takeUnless { it.isBefore(today) }
    }

    fun daysUntil(date: LocalDate, today: LocalDate): Long =
        ChronoUnit.DAYS.between(today, date)

    fun urgencyText(days: Long): String = when {
        days <= 0L -> "Today"
        days == 1L -> "1 day left"
        else -> "$days days left"
    }

    fun isUrgent(days: Long): Boolean = days <= 7L
}

/**
 * Home deadline preview backed by the same published-scholarship search RPC as Explore.
 * Never synthesizes deadlines, changes scholarship data, or labels rolling cycles as dates.
 * The server sorts by deadline; this client filters out missing/invalid/past dates.
 */
@Composable
internal fun HomeClosingSoonContent(onSelect: (Scholarship) -> Unit) {
    var upcoming by remember { mutableStateOf<List<Scholarship>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var retry by remember { mutableIntStateOf(0) }

    LaunchedEffect(retry) {
        loading = true
        error = null
        try {
            val today = LocalDate.now()
            val page = ScholarshipRepository.search(sort = "Deadline", limit = 100)
            upcoming = page.items.mapNotNull { scholarship ->
                HomeDeadlineRules.eligibleUpcomingDate(
                    scholarship.verificationStatus, scholarship.deadline, today
                )?.let { date -> scholarship to date }
            }.sortedBy { it.second }.take(3).map { it.first }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load upcoming deadlines."
        } finally {
            loading = false
        }
    }

    when {
        loading -> {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            Text("Checking published scholarship deadlines…", style = MaterialTheme.typography.bodySmall)
        }
        error != null -> {
            Text(error ?: "Deadlines unavailable.", color = MaterialTheme.colorScheme.error)
            TextButton(onClick = { retry++ }) { Text("Retry deadlines") }
        }
        upcoming.isEmpty() -> Text(
            "No upcoming dated scholarships were found in the current catalog results. Explore all opportunities for more options.",
            style = MaterialTheme.typography.bodySmall
        )
        else -> {
            upcoming.forEach { scholarship ->
                Surface(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)
                        .clickable { onSelect(scholarship) },
                    color = MaterialTheme.colorScheme.surface,
                    shape = RoundedCornerShape(16.dp),
                    tonalElevation = 1.dp
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(scholarship.title, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "${scholarship.provider} · ${scholarship.country}",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            "Deadline: ${scholarship.deadline?.take(10)}",
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.labelMedium
                        )
                        HomeDeadlineRules.parseDate(scholarship.deadline)?.let { date ->
                            val days = HomeDeadlineRules.daysUntil(date, LocalDate.now())
                            if (days >= 0) {
                                Spacer(Modifier.height(3.dp))
                                Text(
                                    HomeDeadlineRules.urgencyText(days),
                                    color = if (HomeDeadlineRules.isUrgent(days))
                                        MaterialTheme.colorScheme.error
                                    else MaterialTheme.colorScheme.primary,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }
                }
            }
            Text(
                "Dates may change. Confirm the current deadline on each provider's official website.",
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}
