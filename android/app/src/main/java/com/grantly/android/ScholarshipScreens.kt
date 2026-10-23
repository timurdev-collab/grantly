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
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

private val forest = Color(0xFF123E30)
private val ink = Color(0xFF19372B)
private val cream = Color(0xFFF8F5ED)
private val sage = Color(0xFFDDEADB)
private val gold = Color(0xFFD9B66E)

@Composable
internal fun ScholarshipDiscoverContent(initialDegree: String = "All", onSelect: (Scholarship) -> Unit) {
    var query by remember { mutableStateOf("") }
    var level by remember(initialDegree) { mutableStateOf(initialDegree) }
    var scholarships by remember { mutableStateOf<List<Scholarship>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var retry by remember { mutableIntStateOf(0) }
    var sort by remember { mutableStateOf("Verified first") }
    var country by remember { mutableStateOf("All") }
    var field by remember { mutableStateOf("All") }
    var funding by remember { mutableStateOf("All") }
    var filterOptions by remember {
        mutableStateOf(ScholarshipFilterOptions(emptyList(), emptyList(), emptyList()))
    }
    var filterError by remember { mutableStateOf(false) }
    var filterRetry by remember { mutableIntStateOf(0) }
    var pageOffset by remember(query, level, sort, country, field, funding) { mutableIntStateOf(0) }
    var totalCount by remember { mutableIntStateOf(0) }
    var loadingMore by remember { mutableStateOf(false) }

    LaunchedEffect(filterRetry) {
        try {
            filterOptions = ScholarshipRepository.filterOptions()
            filterError = false
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            filterError = true
        }
    }

    LaunchedEffect(query, level, sort, country, field, funding, retry, pageOffset) {
        val firstPage = pageOffset == 0
        if (firstPage) {
            loading = true
            scholarships = emptyList()
            totalCount = 0
            if (query.isNotBlank()) delay(350)
        } else {
            loadingMore = true
        }
        error = null
        try {
            val degree = when (level) {
                "Bachelor's" -> "Bachelor"
                "Master's" -> "Master"
                "PhD" -> "PhD"
                else -> null
            }
            val page = ScholarshipRepository.search(
                query = query, degree = degree, sort = sort, offset = pageOffset, limit = 20,
                country = country.takeUnless { it == "All" },
                field = field.takeUnless { it == "All" },
                funding = funding.takeUnless { it == "All" }
            )
            scholarships = if (firstPage) page.items
                else (scholarships + page.items).distinctBy { it.id }
            totalCount = page.totalCount
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load scholarships."
        } finally {
            loading = false
            loadingMore = false
        }
    }

    Text("Discover", fontFamily = FontFamily.Serif, fontSize = 34.sp, color = ink)
    Spacer(Modifier.height(8.dp))
    Text("Curated, verified opportunities for your goals", color = ink.copy(alpha = .7f), fontSize = 14.sp)
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
    Spacer(Modifier.height(12.dp))
    ScholarshipOptionFilter("Country", country, filterOptions.countries) { country = it }
    Spacer(Modifier.height(10.dp))
    ScholarshipOptionFilter("Field of study", field, filterOptions.fields) { field = it }
    Spacer(Modifier.height(10.dp))
    ScholarshipOptionFilter("Funding", funding, filterOptions.funding) { funding = it }
    if (country != "All" || field != "All" || funding != "All") {
        TextButton(onClick = { country = "All"; field = "All"; funding = "All" }) {
            Text("Clear additional filters")
        }
    }
    if (filterError) {
        Text("Additional filter options are unavailable.", color = ink.copy(alpha = .7f), fontSize = 12.sp)
        TextButton(onClick = { filterRetry++ }) { Text("Retry filters") }
    }
    Spacer(Modifier.height(12.dp))
    Text("Sort by", fontWeight = FontWeight.SemiBold, color = forest)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("Verified first", "Recommended", "Deadline").forEach { option ->
            FilterChip(selected = option == sort, onClick = { sort = option }, label = { Text(option, fontSize = 12.sp) })
        }
    }
    Spacer(Modifier.height(20.dp))
    // The RPC applies filters to the full catalog before pagination.
    val results = scholarships
    Text("Scholarship results", fontFamily = FontFamily.Serif, fontSize = 27.sp, color = ink)
    Spacer(Modifier.height(10.dp))
    when {
        loading -> {
            CircularProgressIndicator(color = forest)
            Spacer(Modifier.height(12.dp))
            Text("Finding trusted opportunities...", color = ink.copy(alpha = .7f))
        }
        error != null && results.isEmpty() -> {
            Text(error ?: "Unable to load scholarships.", color = MaterialTheme.colorScheme.error)
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = { retry++ }) { Text("Try again") }
        }
        results.isEmpty() -> {
            Text(
                "No scholarships match these filters.",
                color = ink.copy(alpha = .7f)
            )
        }
        else -> {
            Text("${results.size} of $totalCount opportunities", fontSize = 12.sp, color = ink.copy(alpha = .65f))
            Spacer(Modifier.height(12.dp))
            results.forEach { scholarship ->
                ScholarshipResultCard(scholarship = scholarship, onClick = { onSelect(scholarship) })
                Spacer(Modifier.height(12.dp))
            }
            if (error != null) {
                Text(error ?: "Unable to load more.", color = MaterialTheme.colorScheme.error)
                OutlinedButton(onClick = { retry++ }) { Text("Retry") }
            }
            if (error == null && pageOffset + 20 < totalCount) {
                OutlinedButton(
                    onClick = { pageOffset += 20 },
                    enabled = !loadingMore,
                    modifier = Modifier.fillMaxWidth()
                ) { Text(if (loadingMore) "Loading more..." else "Load more") }
            }
        }
    }
}

@Composable
private fun ScholarshipOptionFilter(
    label: String,
    selected: String,
    options: List<String>,
    onSelected: (String) -> Unit
) {
    Text(label, fontWeight = FontWeight.SemiBold, color = forest)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        (listOf("All") + options).distinct().forEach { option ->
            FilterChip(
                selected = option == selected,
                onClick = { onSelected(option) },
                label = { Text(option, fontSize = 12.sp) }
            )
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
        "Overview" -> {
            Text(scholarship.description ?: "The scholarship provider has not supplied a description.",
                fontSize = 15.sp, lineHeight = 23.sp, color = ink)
            Spacer(Modifier.height(16.dp))
            Text("At a glance", fontWeight = FontWeight.Bold, color = forest)
            Text("Provider: ${scholarship.provider}", color = ink)
            Text("Country: ${scholarship.country}", color = ink)
            Text("Funding: ${scholarship.fundingType}", color = ink)
            Text("Source: ${if (scholarship.verificationStatus == "verified") "Verified" else "Curated"}", color = ink)
            scholarship.reliabilityScore?.let { Text("Data reliability: $it/100", color = ink) }
            scholarship.lastCheckedAt?.let { Text("Last source check: ${it.take(10)}", color = ink) }
        }
        "Eligibility" -> {
            Text("Study levels", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.degreeLevels.joinToString().ifBlank { "Not specified" }, color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Fields of study", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.fields.joinToString().ifBlank { "Not specified" }, color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Minimum GPA", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.minGpaPercent?.let { "${it.toInt()}%" } ?: "Not listed", color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Minimum IELTS", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.minIelts?.toString() ?: "Not listed", color = ink)
            Spacer(Modifier.height(12.dp))
            Text("SAT", fontWeight = FontWeight.Bold, color = forest)
            Text(if (scholarship.satRequired) "Required" else "Not listed as required", color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Confirm nationality, residency and document requirements on the official provider page.",
                color = ink.copy(alpha = .7f), fontSize = 13.sp)
        }
        "Benefits" -> {
            Text("Funding", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.tuitionCoverage ?: scholarship.fundingType, color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Stipend", fontWeight = FontWeight.Bold, color = forest)
            Text(scholarship.stipend ?: "Check official source", color = ink)
            Spacer(Modifier.height(12.dp))
            Text("Airfare: ${if (scholarship.airfare) "Included" else "Not listed"}", color = ink)
            Text("Accommodation: ${if (scholarship.accommodation) "Included" else "Not listed"}", color = ink)
            Text("Health insurance: ${if (scholarship.healthInsurance) "Included" else "Not listed"}", color = ink)
            Spacer(Modifier.height(10.dp))
            Text("Confirm all award conditions with the provider.", fontSize = 13.sp, color = ink.copy(alpha = .7f))
        }
        else -> {
            Text("Current deadline: ${scholarship.deadline?.take(10) ?: "Not yet confirmed"}",
                fontWeight = FontWeight.Bold, color = forest)
            scholarship.deadlineNotes?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, color = ink, fontSize = 14.sp)
            }
            Spacer(Modifier.height(12.dp))
            Text("Verify the application cycle, eligibility, required documents and deadline on the official provider website. Android application tracking is still in development.",
                color = ink, fontSize = 14.sp, lineHeight = 22.sp)
        }
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
