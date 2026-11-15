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
                expected.canonicalFile == candidate.canonicalFile &&
                // Reject symlinks in the staged file or any ancestor directory.
                expected.canonicalFile == expected.absoluteFile
        }
        catch (_: java.io.IOException) { false }
        catch (_: SecurityException) { false }
    }
    private fun valBoxSize(header: ByteArray): Long =
        ((header[0].toLong() and 0xff) shl 24) or
            ((header[1].toLong() and 0xff) shl 16) or
            ((header[2].toLong() and 0xff) shl 8) or
            (header[3].toLong() and 0xff)

    /**
     * Validate a recovered MP4 before it can be read for upload.
     * The caller must supply an app-private root and authenticate accountId.
     * A zero-byte file is not a valid staged video; never follow symlinks.
     */
    fun isSafeStagedMp4(
        root: File,
        candidate: File,
        accountId: String,
        operationId: String,
        maxBytes: Long
    ): Boolean {
        if (maxBytes <= 0 || !matches(root, candidate, accountId, operationId)) return false
        return try {
            val path = candidate.toPath()
            val attrs = java.nio.file.Files.readAttributes(
                path,
                java.nio.file.attribute.BasicFileAttributes::class.java,
                java.nio.file.LinkOption.NOFOLLOW_LINKS
            )
            attrs.isRegularFile && attrs.size() in 16..maxBytes &&
                // Reject mislabeled content before resuming a recovered upload.
                // The MP4 family uses an ISO BMFF 'ftyp' box at byte offset 4.
                java.io.FileInputStream(candidate).use { input ->
                    val header = ByteArray(16)
                    run { java.io.DataInputStream(input).readFully(header); true } &&
                        // ISO BMFF ftyp requires a 16-byte minimum box; reject
                        // truncated or impossible box sizes before upload.
                        valBoxSize(header) in 16..attrs.size() &&
                        header[4] == 'f'.code.toByte() &&
                        header[5] == 't'.code.toByte() &&
                        header[6] == 'y'.code.toByte() &&
                        header[7] == 'p'.code.toByte()
                }
        } catch (_: java.io.IOException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

}
