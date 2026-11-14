package com.grantly.android

import java.io.File
import java.util.UUID

/**
 * Account-scoped local naming for a future durable Community upload coordinator.
 * This does not enable process-death recovery or write upload metadata.
 */
internal object CommunityUploadStagePaths {
    private fun canonicalId(value: String): String? =
        try { UUID.fromString(value).toString().takeIf { it == value } }
        catch (_: IllegalArgumentException) { null }

    /** Never interpolate unvalidated user input into an on-disk path. */
    fun stageFile(root: File, accountId: String, operationId: String): File? {
        val account = canonicalId(accountId) ?: return null
        val operation = canonicalId(operationId) ?: return null
        return File(File(root, account), "$operation.mp4")
    }

    /**
     * Only accept the exact canonical location constructed for this account and operation.
     * A caller must still verify the file is regular, app-private and within size bounds.
     */
    fun matches(root: File, candidate: File, accountId: String, operationId: String): Boolean {
        val expected = stageFile(root, accountId, operationId) ?: return false
        return try {
            // Reject alternate lexical paths (including aliases through ..) before
            // resolving symlinks. A recovery record must name the exact staged file.
            expected.absoluteFile == candidate.absoluteFile &&
                expected.canonicalFile == candidate.canonicalFile
        }
        catch (_: java.io.IOException) { false }
    }
}
