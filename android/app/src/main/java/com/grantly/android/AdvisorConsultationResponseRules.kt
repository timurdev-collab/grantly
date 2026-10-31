package com.grantly.android

import java.io.IOException
import java.io.Reader

/**
 * Limits authenticated consultation responses before JSON parsing and prevents
 * results from being used after sign-out or an account switch.
 *
 * This is client-side defense in depth; Supabase RLS remains authoritative.
 */
internal object AdvisorConsultationResponseRules {
    const val MAX_CHARS = 1_048_576

    fun requireSameAccount(expectedUserId: String, currentUserId: String?) {
        if (expectedUserId != currentUserId) {
            throw IOException("Your account changed. Please sign in again.")
        }
    }

    fun readBounded(reader: Reader): String {
        val buffer = CharArray(4096)
        val body = StringBuilder()
        while (true) {
            val count = reader.read(buffer)
            if (count < 0) break
            if (count > MAX_CHARS - body.length) {
                throw IOException("Consultation response is too large.")
            }
            body.append(buffer, 0, count)
        }
        return body.toString()
    }
}
