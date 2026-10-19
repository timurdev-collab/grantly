package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Navigation bridge while the published scholarship catalog is being integrated.
 * Sample content is explicitly labeled and is NOT a real scholarship.
 */
@Composable
internal fun ScholarshipDiscoverContent(
    initialDegree: String,
    onSelect: (Scholarship) -> Unit
) {
    key(initialDegree) {
        ScholarshipDiscoverContent(onSelect = onSelect)
    }
    Spacer(Modifier.height(18.dp))
    Surface(
        color = Color.White,
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth().clickable {
            onSelect(
                Scholarship(
                    id = "preview-only",
                    title = "Scholarship details preview",
                    provider = "EduT interface demonstration",
                    country = "Sample",
                    fundingType = "Not applicable",
                    degreeLevels = listOf("Bachelor's", "Master's", "PhD"),
                    fields = listOf("Sample field"),
                    deadline = null,
                    description = "This is a demonstration of Android navigation and detail tabs. It is not a scholarship offer.",
                    officialUrl = null,
                    verificationStatus = null
                )
            )
        }
    ) {
        Column(Modifier.padding(18.dp)) {
            Text("PREVIEW ONLY · NOT A REAL SCHOLARSHIP", color = Color(0xFF123E30), style = MaterialTheme.typography.labelSmall)
            Spacer(Modifier.height(8.dp))
            Text("Tap to test scholarship details", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(5.dp))
            Text("Overview, Eligibility, Benefits and Application", style = MaterialTheme.typography.bodySmall)
        }
    }
}
