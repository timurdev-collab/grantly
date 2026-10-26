package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import java.time.LocalDate

/**
 * Read-only Home hero matching iOS's priority: the signed-in user's best
 * scholarship match, then an upcoming published scholarship, then Explore.
 * This never creates a recommendation or invents a provider deadline.
 */
@Composable
internal fun HomeFeaturedScholarshipContent(
    onSelect: (Scholarship) -> Unit,
    onExplore: () -> Unit
) {
    val userId = AuthRepository.session?.userId
    var featured by remember(userId) { mutableStateOf<Scholarship?>(null) }
    var matchScore by remember(userId) { mutableStateOf<Int?>(null) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var retry by remember(userId) { mutableIntStateOf(0) }

    LaunchedEffect(userId, retry) {
        loading = true
        error = null
        featured = null
        matchScore = null
        try {
            // A failed private matching request must not prevent public discovery.
            val match = if (userId == null) null else try {
                PersonalizedMatchesRepository.top(limit = 1).firstOrNull()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                null
            }
            if (match != null) {
                featured = match.scholarship
                matchScore = match.score
            } else {
                val today = LocalDate.now()
                featured = ScholarshipRepository.search(sort = "Deadline", limit = 100)
                    .items.mapNotNull { scholarship ->
                        val date = scholarship.deadline?.take(10)?.let { raw ->
                            runCatching { LocalDate.parse(raw) }.getOrNull()
                        }
                        if (date != null && !date.isBefore(today)) scholarship to date else null
                    }
                    .minByOrNull { it.second }?.first
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load featured scholarships."
        } finally {
            loading = false
        }
    }

    val forest = Color(0xFF082D23)
    val ivory = Color(0xFFF8F5ED)
    val sage = Color(0xFFDDEADB)
    val gold = Color(0xFFD9B66E)
    Column(
        modifier = Modifier.fillMaxWidth()
            .clickable(enabled = !loading) {
                featured?.let(onSelect) ?: onExplore()
            }
            .then(Modifier)
            .padding(0.dp)
    ) {
        Surface(color = forest, shape = RoundedCornerShape(24.dp)) {
            Column(Modifier.fillMaxWidth().padding(24.dp)) {
                Text(
                    when {
                        matchScore != null -> "YOUR BEST MATCH"
                        featured != null -> "FEATURED OPPORTUNITY"
                        else -> "FIND YOUR SCHOLARSHIP"
                    },
                    color = gold, fontSize = 11.sp, letterSpacing = 2.sp
                )
                Spacer(Modifier.height(12.dp))
                if (loading) {
                    LinearProgressIndicator(
                        modifier = Modifier.fillMaxWidth(),
                        color = gold,
                        trackColor = sage.copy(alpha = 0.25f)
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("Finding available scholarships…", color = sage)
                } else if (featured != null) {
                    Text(
                        featured!!.title,
                        fontFamily = FontFamily.Serif,
                        fontSize = 25.sp,
                        lineHeight = 31.sp,
                        color = ivory
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(
                        listOf(featured!!.provider, featured!!.country)
                            .filter { it.isNotBlank() }.joinToString(" · "),
                        color = sage, fontSize = 13.sp
                    )
                    matchScore?.let { score ->
                        Spacer(Modifier.height(7.dp))
                        Text("$score% profile match · Verify eligibility with the provider",
                            color = gold, fontSize = 12.sp)
                    } ?: featured!!.deadline?.take(10)?.let { date ->
                        Spacer(Modifier.height(7.dp))
                        Text("Listed deadline: $date · Confirm with provider",
                            color = gold, fontSize = 12.sp)
                    }
                    Spacer(Modifier.height(14.dp))
                    Text("View scholarship →", color = ivory, fontWeight = FontWeight.SemiBold)
                } else {
                    Text(
                        "Find the right scholarship\nfor your next chapter.",
                        fontFamily = FontFamily.Serif,
                        fontSize = 27.sp,
                        lineHeight = 33.sp,
                        color = ivory
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        if (error != null) "Featured scholarships are temporarily unavailable."
                        else "Explore published opportunities and complete your profile for personalized matches.",
                        color = sage, fontSize = 13.sp, lineHeight = 19.sp
                    )
                    Spacer(Modifier.height(14.dp))
                    Text("Explore scholarships →", color = ivory, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        if (error != null) {
            TextButton(onClick = { retry++ }) { Text("Retry featured scholarship") }
        }
    }
}
