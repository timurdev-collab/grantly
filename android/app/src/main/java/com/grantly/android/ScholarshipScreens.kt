package com.grantly.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.net.URI

private val forest = Color(0xFF123E30)
private val ink = Color(0xFF19372B)
private val cream = Color(0xFFF8F5ED)
private val sage = Color(0xFFDDEADB)
private val gold = Color(0xFFD9B66E)

@Composable
internal fun ScholarshipDiscoverContent(onSelect: (Scholarship) -> Unit) {
    var query by remember { mutableStateOf("") }
    var level by remember { mutableStateOf("All") }
    var scholarships by remember { mutableStateOf<List<Scholarship>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var retry by remember { mutableIntStateOf(0) }

    LaunchedEffect(retry) {
        loading = true
        error = null
        try {
            scholarships = ScholarshipRepository.fetchPublished()
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load scholarships."
        } finally {
            loading = false
        }
    }

    Text("Explore opportunities", fontFamily = FontFamily.Serif, fontSize = 34.sp, color = ink)
    Spacer(Modifier.height(8.dp))
    Text("Discover verified scholarships aligned with your plans.", color = ink.copy(alpha = .7f), fontSize = 14.sp)
    Spacer(Modifier.height(18.dp))
    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
        label = { Text("Search scholarships, universities, countries") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp)
    )
    Spacer(Modifier.height(14.dp))
    Text("Study level", fontWeight = FontWeight.SemiBold, color = forest)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("All", "Bachelor's", "Master's", "PhD").forEach { option ->
            FilterChip(selected = option == level, onClick = { level = option }, label = { Text(option, fontSize = 12.sp) })
        }
    }
    Spacer(Modifier.height(20.dp))
    val results = scholarships.filter { scholarship ->
        (query.isBlank() || listOf(scholarship.title, scholarship.provider, scholarship.country)
            .any { it.contains(query.trim(), ignoreCase = true) }) &&
        (level == "All" || scholarship.degreeLevels.any {
            when (level) {
                "Bachelor's" -> it.contains("bachelor", ignoreCase = true) || it.contains("undergrad", ignoreCase = true)
                "Master's" -> it.contains("master", ignoreCase = true)
                else -> it.contains("phd", ignoreCase = true) || it.contains("doctor", ignoreCase = true)
            }
        })
    }
    Text("Scholarship results", fontFamily = FontFamily.Serif, fontSize = 27.sp, color = ink)
    Spacer(Modifier.height(10.dp))
    when {
        loading -> {
            CircularProgressIndicator(color = forest)
            Spacer(Modifier.height(12.dp))
            Text("Finding trusted opportunities...", color = ink.copy(alpha = .7f))
        }
        error != null -> {
            Text(error ?: "Unable to load scholarships.", color = MaterialTheme.colorScheme.error)
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = { retry++ }) { Text("Try again") }
        }
        results.isEmpty() -> {
            Text(
                if (scholarships.isEmpty()) "No published scholarships are visible to this session yet."
                else "No scholarships match these filters.",
                color = ink.copy(alpha = .7f)
            )
        }
        else -> {
            Text("${results.size} opportunities", fontSize = 12.sp, color = ink.copy(alpha = .65f))
            Spacer(Modifier.height(12.dp))
            results.forEach { scholarship ->
                ScholarshipResultCard(scholarship = scholarship, onClick = { onSelect(scholarship) })
                Spacer(Modifier.height(12.dp))
            }
        }
    }
}

@Composable
private fun ScholarshipResultCard(scholarship: Scholarship, onClick: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick).padding(19.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(scholarship.country, color = forest, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            if (scholarship.verificationStatus == "verified") {
                Text("Verified", color = forest, fontSize = 11.sp)
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(scholarship.title, fontFamily = FontFamily.Serif, fontSize = 22.sp, lineHeight = 27.sp, color = ink)
        Spacer(Modifier.height(6.dp))
        Text(scholarship.provider, color = ink.copy(alpha = .7f), fontSize = 13.sp)
        Spacer(Modifier.height(12.dp))
        Text(scholarship.fundingType + (scholarship.deadline?.let { "  ·  Deadline: ${it.take(10)}" } ?: ""),
            color = forest, fontSize = 12.sp)
        Spacer(Modifier.height(9.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("View details", color = forest, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            Spacer(Modifier.width(6.dp))
            Icon(Icons.Outlined.ArrowForward, null, tint = forest, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
internal fun ScholarshipDetailContent(scholarship: Scholarship, onBack: () -> Unit) {
    var selectedTab by remember(scholarship.id) { mutableStateOf("Overview") }
    val uriHandler = LocalUriHandler.current
    val safeUrl = remember(scholarship.officialUrl) {
        scholarship.officialUrl?.takeIf { raw ->
            try {
                val uri = URI(raw)
                uri.scheme.equals("https", ignoreCase = true) && !uri.host.isNullOrBlank()
            } catch (_: Exception) { false }
        }
    }
    TextButton(onClick = onBack) {
        Icon(Icons.Outlined.ArrowBack, contentDescription = null)
        Spacer(Modifier.width(7.dp))
        Text("Back to Explore")
    }
    Spacer(Modifier.height(12.dp))
    Column(Modifier.fillMaxWidth().background(forest, RoundedCornerShape(22.dp)).padding(22.dp)) {
        if (scholarship.verificationStatus == "verified") {
            Text("VERIFIED", fontSize = 11.sp, color = gold, letterSpacing = 2.sp)
            Spacer(Modifier.height(10.dp))
        }
        Text(scholarship.title, fontFamily = FontFamily.Serif, fontSize = 30.sp, lineHeight = 35.sp, color = cream)
        Spacer(Modifier.height(12.dp))
        Text(scholarship.provider, color = sage, fontSize = 14.sp)
    }
    Spacer(Modifier.height(17.dp))
    Text(scholarship.country, color = ink, fontWeight = FontWeight.SemiBold)
    scholarship.deadline?.let {
        Spacer(Modifier.height(6.dp))
        Text("Deadline: ${it.take(10)}", color = ink.copy(alpha = .7f), fontSize = 13.sp)
    }
    Spacer(Modifier.height(15.dp))
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("Overview", "Eligibility", "Benefits", "Application").forEach { tab ->
            FilterChip(selected = tab == selectedTab, onClick = { selectedTab = tab }, label = { Text(tab) })
        }
    }
    Spacer(Modifier.height(18.dp))
    when (selectedTab) {
        "Overview" -> Text(scholarship.description ?: "The scholarship provider has not supplied a description.",
            fontSize = 15.sp, lineHeight = 23.sp, color = ink)
        "Eligibility" -> {
            Text("Study levels", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.degreeLevels.joinToString().ifBlank { "Not specified" }, color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Fields of study", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.fields.joinToString().ifBlank { "Not specified" }, color = ink)
        }
        "Benefits" -> {
            Text("Funding", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.fundingType, color = ink)
            Text("Check the official provider page for full award conditions.", fontSize = 13.sp, color = ink.copy(alpha = .7f))
        }
        else -> Text("Review the official scholarship website for application instructions. Android application tracking is still in development.",
            color = ink, fontSize = 14.sp, lineHeight = 22.sp)
    }
    Spacer(Modifier.height(24.dp))
    if (safeUrl != null) {
        Button(
            onClick = { uriHandler.openUri(safeUrl) },
            colors = ButtonDefaults.buttonColors(containerColor = forest),
            modifier = Modifier.fillMaxWidth()
        ) { Text("Open official scholarship page") }
    }
}
