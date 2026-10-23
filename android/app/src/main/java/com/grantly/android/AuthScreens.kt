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

@Composable
internal fun AuthContent() {
    val session = AuthRepository.session
    val scope = rememberCoroutineScope()
    if (AuthRepository.isRestoring) {
        CircularProgressIndicator(color = authForest)
        Spacer(Modifier.height(12.dp))
        Text("Restoring your account securely…", color = authInk)
        return
    }
    if (AuthRepository.needsPasswordReset) {
        RecoveryPasswordContent()
        return
    }

    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val recoveryError = AuthRepository.recoveryError
    if (recoveryError != null) {
        Text(recoveryError, color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
        Spacer(Modifier.height(12.dp))
    }

    if (session != null) {
        Text("Your account", fontFamily = FontFamily.Serif, fontSize = 34.sp, color = authInk)
        Spacer(Modifier.height(12.dp))
        Text("Signed in as ${session.email}", color = authInk)
        Spacer(Modifier.height(12.dp))
        Text("Your saved scholarships and application tracker are connected. Profile editing is still being ported.",
            color = authInk.copy(alpha = .7f))
        Spacer(Modifier.height(10.dp))
        Text("Your session is encrypted on this device and restored when you reopen EduT.",
            color = authInk.copy(alpha = .7f), fontSize = 12.sp)
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
    var isRecovering by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmationSent by remember { mutableStateOf(false) }
    var resetSent by remember { mutableStateOf(false) }
    val normalized = email.trim()
    val validEmail = normalized.length <= 254 && normalized.contains('@') &&
        normalized.substringAfterLast('@').contains('.') && !normalized.contains(' ')
    val validPassword = if (isSignup) password.length in 8..128 else password.isNotEmpty()

    Text(
        when {
            isRecovering -> if (resetSent) "Check your email" else "Reset password"
            isSignup -> "Create your account"
            else -> "Welcome back"
        },
        fontFamily = FontFamily.Serif, fontSize = 34.sp, color = authInk
    )
    Spacer(Modifier.height(10.dp))
    Text(
        when {
            resetSent && isRecovering -> "If this address has an account, a reset link will arrive. Open it on this Android device to choose a new password."
            isRecovering -> "Enter the email address used for your EduT account."
            isSignup -> "Start building your scholarship shortlist."
            else -> "Sign in with your existing EduT account."
        },
        color = authInk.copy(alpha = .7f)
    )
    Spacer(Modifier.height(22.dp))
    if (!resetSent || !isRecovering) {
        OutlinedTextField(
            value = email,
            onValueChange = { email = it; error = null; confirmationSent = false },
            label = { Text("Email") }, singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)
        )
        if (!isRecovering) {
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = password,
                onValueChange = { password = it; error = null },
                label = { Text(if (isSignup) "Password (8–128 characters)" else "Password") },
                singleLine = true, visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)
            )
        }
    }
    if (error != null) {
        Spacer(Modifier.height(10.dp))
        Text(error ?: "", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
    }
    if (confirmationSent) {
        Spacer(Modifier.height(12.dp))
        Text("Account request received. Check your email to confirm, then sign in.", color = authForest)
    }
    Spacer(Modifier.height(20.dp))
    if (!resetSent || !isRecovering) {
        Button(
            enabled = validEmail && (isRecovering || validPassword) && !busy,
            onClick = {
                busy = true
                error = null
                scope.launch {
                    try {
                        when {
                            isRecovering -> {
                                AuthRepository.requestPasswordReset(email)
                                resetSent = true
                            }
                            isSignup -> {
                                AuthRepository.signUp(email, password)
                                confirmationSent = true
                            }
                            else -> AuthRepository.signIn(email, password)
                        }
                        password = ""
                    } catch (failure: Exception) {
                        error = failure.message ?: "Unable to connect to your account."
                    } finally { busy = false }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = authForest),
            shape = RoundedCornerShape(16.dp)
        ) {
            Text(if (busy) "Please wait…" else when {
                isRecovering -> "Send reset email"
                isSignup -> "Create account"
                else -> "Sign in"
            })
        }
    }
    Spacer(Modifier.height(12.dp))
    if (!isRecovering && !isSignup) {
        TextButton(onClick = {
            isRecovering = true
            error = null
            password = ""
        }) { Text("Forgot password?") }
    }
    TextButton(onClick = {
        isRecovering = false
        isSignup = if (isRecovering) false else !isSignup
        error = null
        confirmationSent = false
        resetSent = false
        password = ""
    }) {
        Text(if (isRecovering) "Back to sign in"
            else if (isSignup) "Already have an account? Sign in"
            else "New to EduT? Create an account")
    }
    Spacer(Modifier.height(12.dp))
    Text("Android account preview: recovery links require the EduT app on this device.",
        color = authInk.copy(alpha = .65f), fontSize = 12.sp)
}

@Composable
private fun RecoveryPasswordContent() {
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    Text("Choose a new password", fontFamily = FontFamily.Serif, fontSize = 32.sp, color = authInk)
    Spacer(Modifier.height(10.dp))
    Text("Your recovery link has been verified. Set a new password for your EduT account.",
        color = authInk.copy(alpha = .7f))
    Spacer(Modifier.height(18.dp))
    OutlinedTextField(
        value = password, onValueChange = { password = it; error = null },
        label = { Text("New password (at least 8 characters)") },
        singleLine = true, visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = confirmation, onValueChange = { confirmation = it; error = null },
        label = { Text("Confirm new password") },
        singleLine = true, visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        modifier = Modifier.fillMaxWidth()
    )
    if (confirmation.isNotEmpty() && password != confirmation) {
        Text("Passwords do not match.", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
    }
    if (error != null) {
        Spacer(Modifier.height(8.dp))
        Text(error ?: "", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
    }
    Spacer(Modifier.height(18.dp))
    Button(
        enabled = password.length in 8..128 && password == confirmation && !busy,
        onClick = {
            busy = true
            scope.launch {
                try {
                    AuthRepository.updateRecoveredPassword(password)
                    password = ""
                    confirmation = ""
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to update password."
                } finally { busy = false }
            }
        },
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(containerColor = authForest)
    ) { Text(if (busy) "Updating…" else "Update password") }
}
