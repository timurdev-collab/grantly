package com.grantly.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private val profileForest = Color(0xFF123E30)
private val profileInk = Color(0xFF19372B)

/** Signed-in academic profile, backed by the existing private student_profiles table. */
@Composable
internal fun StudentProfileContent(userId: String) {
    val scope = rememberCoroutineScope()
    var profile by remember(userId) { mutableStateOf<StudentProfileDraft?>(null) }
    var draft by remember(userId) { mutableStateOf(StudentProfileDraft()) }
    var editing by remember(userId) { mutableStateOf(false) }
    var loading by remember(userId) { mutableStateOf(true) }
    var saving by remember(userId) { mutableStateOf(false) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var success by remember(userId) { mutableStateOf(false) }
    var reload by remember(userId) { mutableIntStateOf(0) }
    var showingAdminDrafts by remember(userId) { mutableStateOf(false) }
    var showingAdminAdvisors by remember(userId) { mutableStateOf(false) }
    var showingAdvisorApplication by remember(userId) { mutableStateOf(false) }
    var showingAdvisorPortal by remember(userId) { mutableStateOf(false) }
    var advisorApplicationRefresh by remember(userId) { mutableIntStateOf(0) }

    LaunchedEffect(userId, reload) {
        loading = true
        profile = null // Fail closed while revalidating the role and profile.
        error = null
        try {
            val result = StudentProfileRepository.load()
            if (AuthRepository.session?.userId == userId) {
                profile = result
                draft = result
                editing = false
                showingAdvisorPortal = false
            }
        } catch (cancelled: CancellationException) {
            // Navigating away cancels the request; it is not a profile-load failure.
            throw cancelled
        } catch (failure: Exception) {
            profile = null
            editing = false
            error = failure.message ?: "Unable to load your academic profile."
        } finally {
            loading = false
        }
    }

    Text("Your profile", fontFamily = FontFamily.Serif, fontSize = 32.sp, color = profileInk)
    Spacer(Modifier.height(8.dp))
    Text("Academic details are private and help personalize scholarship matching.",
        fontSize = 13.sp, color = profileInk.copy(alpha = .7f))
    Spacer(Modifier.height(16.dp))

    if (loading) {
        CircularProgressIndicator(color = profileForest)
        Spacer(Modifier.height(10.dp))
        Text("Loading your academic profile…", color = profileInk)
        return
    }
    if (error != null) {
        Text(error ?: "", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = { reload++ }) { Text("Retry loading") }
        Spacer(Modifier.height(14.dp))
    }
    val saved = profile ?: return
    BackHandler(enabled = showingAdvisorPortal && saved.role == "advisor") {
        showingAdvisorPortal = false
    }
    if (saved.role == "advisor" && showingAdvisorPortal) {
        AdvisorPortalContent(userId = userId, onBack = { showingAdvisorPortal = false })
        return
    }
    if (success) {
        Text("Profile saved.", color = profileForest, fontSize = 13.sp)
        Spacer(Modifier.height(12.dp))
    }

    Text(saved.fullName.ifBlank { "Your EduT profile" },
        fontSize = 23.sp, fontWeight = FontWeight.SemiBold, color = profileInk)
    Spacer(Modifier.height(6.dp))
    Text("Account role: ${saved.role}", color = profileInk.copy(alpha = .7f), fontSize = 12.sp)
    Spacer(Modifier.height(14.dp))
    // Match iOS: profile photos are stored separately from private academic details.
    ProfileAvatarContent(userId = userId, fullName = saved.fullName)
    if (saved.role == "advisor") {
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { showingAdvisorPortal = true },
            modifier = Modifier.fillMaxWidth()
        ) { Text("Open Advisor Portal") }
    }
    // Students can apply; advisors can inspect their application status.
    // Approved advisor profile editing is a separate workflow not yet implemented here.
    // Status and submission use the existing RLS-protected advisor endpoints.
    if (saved.role == "student" || saved.role == "advisor") {
        key(advisorApplicationRefresh) {
            AdvisorApplicationStatusContent(userId = userId)
        }
        OutlinedButton(
            onClick = { showingAdvisorApplication = !showingAdvisorApplication },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (showingAdvisorApplication) "Close advisor application"
                else if (saved.role == "advisor") "View advisor application"
                else "Apply as an advisor")
        }
        if (showingAdvisorApplication) {
            Spacer(Modifier.height(12.dp))
            AdvisorApplicationFormContent(
                userId = userId,
                defaultName = saved.fullName,
                onSubmitted = {
                    showingAdvisorApplication = false
                    advisorApplicationRefresh++
                }
            )
        }
        Spacer(Modifier.height(12.dp))
    }
    Text("Academic profile · ${saved.completion}% complete",
        fontWeight = FontWeight.SemiBold, color = profileForest)
    Spacer(Modifier.height(8.dp))
    LinearProgressIndicator(
        progress = { saved.completion / 100f },
        modifier = Modifier.fillMaxWidth(),
        color = profileForest
    )
    Spacer(Modifier.height(14.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        ProfileMetric("GPA", saved.gpaValue.ifBlank { "—" }, Modifier.weight(1f))
        ProfileMetric("IELTS", saved.ielts.ifBlank { "—" }, Modifier.weight(1f))
        ProfileMetric("Graduation", saved.graduationYear.ifBlank { "—" }, Modifier.weight(1f))
    }
    Spacer(Modifier.height(14.dp))
    Text("Study goals", fontSize = 20.sp, fontFamily = FontFamily.Serif, color = profileInk)
    Spacer(Modifier.height(6.dp))
    Text("Degree: ${saved.degreeLevel}", color = profileInk)
    Text("Major: ${saved.intendedMajor.ifBlank { "Not set" }}", color = profileInk)
    Text("Countries: ${saved.targetCountries.ifBlank { "Not set" }}", color = profileInk)
    Spacer(Modifier.height(16.dp))

    // Advisor tools live in a separate portal; no duplicate role controls here.

    // Only a successfully loaded admin role can reveal the read-only queue.
    // The queue also rechecks the role and relies on existing server-side RLS.
    if (saved.role == "admin") {
        HorizontalDivider()
        Spacer(Modifier.height(14.dp))
        OutlinedButton(
            onClick = { showingAdminDrafts = !showingAdminDrafts },
            modifier = Modifier.fillMaxWidth()
        ) { Text(if (showingAdminDrafts) "Hide admin draft queue" else "Review draft scholarships") }
        if (showingAdminDrafts) {
            Spacer(Modifier.height(12.dp))
            AdminDraftQueueContent(userId = userId)
        }
        OutlinedButton(
            onClick = { showingAdminAdvisors = !showingAdminAdvisors },
            modifier = Modifier.fillMaxWidth()
        ) { Text(if (showingAdminAdvisors) "Hide advisor applications" else "Review advisor applications") }
        if (showingAdminAdvisors) {
            Spacer(Modifier.height(12.dp))
            AdminAdvisorApplicationsContent(userId = userId)
        }
        Spacer(Modifier.height(16.dp))
    }

    if (!editing) {
        Button(
            onClick = { draft = saved; editing = true; success = false; error = null },
            colors = ButtonDefaults.buttonColors(containerColor = profileForest),
            modifier = Modifier.fillMaxWidth()
        ) { Text("Edit academic profile") }
        Spacer(Modifier.height(10.dp))
        OutlinedButton(onClick = { reload++ }, modifier = Modifier.fillMaxWidth()) {
            Text("Refresh profile")
        }
        return
    }

    HorizontalDivider()
    Spacer(Modifier.height(14.dp))
    Text("Edit academic profile", fontSize = 22.sp, fontFamily = FontFamily.Serif, color = profileInk)
    Spacer(Modifier.height(8.dp))
    ProfileField("Full name", draft.fullName) { draft = draft.copy(fullName = it) }
    ProfileField("Nationality", draft.nationality) { draft = draft.copy(nationality = it) }
    ProfileField("Country of residence", draft.residenceCountry) {
        draft = draft.copy(residenceCountry = it)
    }
    ProfileField("Graduation year", draft.graduationYear, KeyboardType.Number) {
        draft = draft.copy(graduationYear = it)
    }
    ProfileField("GPA", draft.gpaValue, KeyboardType.Decimal) {
        draft = draft.copy(gpaValue = it)
    }
    ProfileField("GPA scale", draft.gpaScale, KeyboardType.Decimal) {
        draft = draft.copy(gpaScale = it)
    }
    ProfileField("IELTS score", draft.ielts, KeyboardType.Decimal) {
        draft = draft.copy(ielts = it)
    }
    ProfileField("Intended major", draft.intendedMajor) {
        draft = draft.copy(intendedMajor = it)
    }
    Text("Degree level", fontWeight = FontWeight.Medium, color = profileInk)
    Spacer(Modifier.height(6.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        listOf("Bachelor", "Master", "PhD").forEach { degree ->
            FilterChip(
                selected = draft.degreeLevel == degree,
                onClick = { draft = draft.copy(degreeLevel = degree) },
                label = { Text(degree) }
            )
        }
    }
    ProfileField("Target regions (comma separated)", draft.targetRegions) {
        draft = draft.copy(targetRegions = it)
    }
    ProfileField("Target countries (comma separated)", draft.targetCountries) {
        draft = draft.copy(targetCountries = it)
    }
    ProfileField("Annual family income (USD)", draft.familyIncome, KeyboardType.Decimal) {
        draft = draft.copy(familyIncome = it)
    }
    Spacer(Modifier.height(6.dp))
    Text("Your GPA, IELTS, income and residence details are not published to the community.",
        fontSize = 12.sp, color = profileInk.copy(alpha = .7f))
    Spacer(Modifier.height(14.dp))
    Button(
        enabled = !saving && draft.fullName.isNotBlank(),
        onClick = {
            saving = true
            error = null
            success = false
            scope.launch {
                try {
                    val updated = StudentProfileRepository.save(draft)
                    if (AuthRepository.session?.userId == userId) {
                        profile = updated
                        draft = updated
                        editing = false
                        success = true
                    }
                } catch (cancelled: CancellationException) {
                    // Do not swallow structured cancellation during navigation or logout.
                    throw cancelled
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to save your profile."
                } finally { saving = false }
            }
        },
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(containerColor = profileForest)
    ) { Text(if (saving) "Saving…" else "Save profile") }
    Spacer(Modifier.height(8.dp))
    OutlinedButton(
        enabled = !saving,
        onClick = { draft = saved; editing = false; error = null },
        modifier = Modifier.fillMaxWidth()
    ) { Text("Cancel editing") }
}

@Composable
private fun ProfileMetric(label: String, value: String, modifier: Modifier = Modifier) {
    Surface(modifier = modifier, color = Color.White, shape = RoundedCornerShape(14.dp)) {
        Column(Modifier.padding(10.dp)) {
            Text(value, color = profileInk, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Spacer(Modifier.height(4.dp))
            Text(label, color = profileInk.copy(alpha = .7f), fontSize = 11.sp)
        }
    }
}

@Composable
private fun ProfileField(
    label: String,
    value: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    onChange: (String) -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp)
    )
    Spacer(Modifier.height(10.dp))
}
