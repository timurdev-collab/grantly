package com.grantly.android

/**
 * Keep Android's email and password checks aligned with the iOS AuthValidation
 * implementation. These are UI preflight checks, not a replacement for Supabase
 * authentication or server-side validation.
 */
internal object AuthValidation {
    fun normalizedEmail(value: String): String = value.trim().lowercase()

    fun isValidEmail(value: String): Boolean {
        val email = normalizedEmail(value)
        if (email.isEmpty() || email.length > 254) return false
        val at = email.lastIndexOf('@')
        if (at <= 0 || at == email.lastIndex) return false
        val local = email.substring(0, at)
        val domain = email.substring(at + 1)
        return local.isNotEmpty() &&
            domain.contains('.') &&
            !domain.startsWith('.') &&
            !domain.endsWith('.') &&
            !email.contains(' ')
    }

    fun passwordIssue(password: String): String? = when {
        password.length < 8 -> "Use at least 8 characters."
        password.length > 128 -> "Password is too long."
        else -> null
    }
}
