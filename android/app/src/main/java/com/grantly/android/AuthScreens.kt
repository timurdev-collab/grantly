package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

private val authForest = Color(0xFF123E30)
private val authInk = Color(0xFF19372B)

/** First Android authentication surface; account-dependent tabs are not yet ported. */
@Composable
internal fun AuthContent() {
    val session = AuthRepository.session
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    if (session != null) {
        Text("Your account", fontFamily = FontFamily.Serif, fontSize = 34.sp, color = authInk)
        Spacer(Modifier.height(12.dp))
        Text("Signed in as ${session.email}", color = authInk)
        Spacer(Modifier.height(12.dp))
        Text(
            "Your account is connected for this app session. Saved scholarships, application tracking and profile editing are still being ported.",
            color = authInk.copy(alpha = .7f)
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Preview limitation: your session is not saved when the app closes.",
            color = authInk.copy(alpha = .7f),
            fontSize = 12.sp
        )
        Spacer(Modifier.height(18.dp))
        OutlinedButton(enabled = !busy, onClick = {
            busy = true
            scope.launch {
                try { AuthRepository.signOut() }
                finally { busy = false }
            }
        }) { Text(if (busy) "Signing out…" else "Sign out") }
        return
    }

    var isSignup by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmationSent by remember { mutableStateOf(false) }
    val normalized = email.trim()
    val validEmail = normalized.length <= 254 &&
        normalized.contains('@') &&
        normalized.substringAfterLast('@').contains('.') &&
        !normalized.contains(' ')
    val validPassword = if (isSignup) password.length in 8..128 else password.isNotEmpty()

    Text(
        if (isSignup) "Create your account" else "Welcome back",
        fontFamily = FontFamily.Serif, fontSize = 34.sp, color = authInk
    )
    Spacer(Modifier.height(10.dp))
    Text(
        if (isSignup) "Start building your scholarship shortlist."
        else "Sign in with your existing EduT account.",
        color = authInk.copy(alpha = .7f)
    )
    Spacer(Modifier.height(22.dp))
    OutlinedTextField(
        value = email,
        onValueChange = { email = it; error = null; confirmationSent = false },
        label = { Text("Email") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    )
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = password,
        onValueChange = { password = it; error = null },
        label = { Text(if (isSignup) "Password (8–128 characters)" else "Password") },
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    )
    if (error != null) {
        Spacer(Modifier.height(10.dp))
        Text(error ?: "", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
    }
    if (confirmationSent) {
        Spacer(Modifier.height(12.dp))
        Text("Account request received. Check your email to confirm, then sign in.", color = authForest)
    }
    Spacer(Modifier.height(20.dp))
    Button(
        enabled = validEmail && validPassword && !busy,
        onClick = {
            busy = true
            error = null
            scope.launch {
                try {
                    if (isSignup) {
                        AuthRepository.signUp(email, password)
                        confirmationSent = true
                    } else {
                        AuthRepository.signIn(email, password)
                    }
                    password = ""
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to connect to your account."
                } finally {
                    busy = false
                }
            }
        },
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(containerColor = authForest),
        shape = RoundedCornerShape(16.dp)
    ) {
        Text(if (busy) "Please wait…" else if (isSignup) "Create account" else "Sign in")
    }
    Spacer(Modifier.height(12.dp))
    TextButton(onClick = {
        isSignup = !isSignup
        error = null
        confirmationSent = false
        password = ""
    }) {
        Text(if (isSignup) "Already have an account? Sign in" else "New to EduT? Create an account")
    }
    Spacer(Modifier.height(12.dp))
    Text(
        "This is an Android authentication preview. Password recovery and secure session restoration are not available yet.",
        color = authInk.copy(alpha = .65f),
        fontSize = 12.sp
    )
}
