package com.grantly.android

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.nio.file.StandardOpenOption
import java.util.UUID

/**
 * Small crash-safe phase journal for a future Community upload coordinator.
 * It stores no credentials, URLs, captions or media bytes. Not wired to uploads yet.
 * Callers must supply an app-private root and serialize writes per operation.
 */
internal object CommunityUploadPhaseJournal {
    private fun canonicalUuid(value: String): Boolean =
        try { UUID.fromString(value).toString() == value }
        catch (_: IllegalArgumentException) { false }

    private fun journal(root: File, accountId: String, operationId: String): File? {
        if (!canonicalUuid(accountId) || !canonicalUuid(operationId)) return null
        return File(File(root, accountId), "$operationId.phase")
    }

    /** Fail closed if a symlink or noncanonical path is encountered. */
    private fun safePath(root: File, file: File): Boolean = try {
        root.canonicalFile == root.absoluteFile &&
            file.canonicalFile == file.absoluteFile &&
            file.parentFile.canonicalFile == file.parentFile.absoluteFile
    } catch (_: java.io.IOException) { false } catch (_: SecurityException) { false }

    fun read(root: File, accountId: String, operationId: String): CommunityUploadCheckpointRules.Phase? {
        val file = journal(root, accountId, operationId) ?: return null
        if (!safePath(root, file) || !file.isFile || file.length() > 80) return null
        return try {
            val lines = file.readLines(Charsets.UTF_8)
            if (lines.size != 2 || lines[0] != "edut-phase-v1") null
            else CommunityUploadCheckpointRules.Phase.values().firstOrNull { it.name == lines[1] }
        } catch (_: java.io.IOException) { null } catch (_: SecurityException) { null }
    }

    /**
     * Atomically replace a journal entry. Never downgrade an existing phase or
     * write INSERT_ATTEMPTED without first persisting PUBLISH_PENDING.
     * No non-atomic fallback: unsupported filesystems must fail closed.
     */
    @Synchronized
    fun write(
        root: File,
        accountId: String,
        operationId: String,
        phase: CommunityUploadCheckpointRules.Phase
    ): Boolean {
        val file = journal(root, accountId, operationId) ?: return false
        if (!safePath(root, file)) return false
        val parent = file.parentFile
        if (!parent.isDirectory && !parent.mkdirs()) return false
        if (!safePath(root, file)) return false
        val previous = read(root, accountId, operationId)
        if (file.exists() && previous == null) return false
        if (previous == null && phase != CommunityUploadCheckpointRules.Phase.STAGED) return false
        if (previous != null && !CommunityUploadCheckpointRules.canTransition(previous, phase)) return false
        val tmp = File(parent, "$operationId.phase.tmp")
        if (!safePath(root, tmp) || tmp.exists()) return false
        return try {
            val bytes = "edut-phase-v1\n${phase.name}\n".toByteArray(Charsets.UTF_8)
            java.nio.channels.FileChannel.open(tmp.toPath(), StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE).use { channel ->
                val buffer = java.nio.ByteBuffer.wrap(bytes)
                while (buffer.hasRemaining()) channel.write(buffer)
                channel.force(true)
            }
            Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
            true
        } catch (_: java.io.IOException) {
            false
        } catch (_: SecurityException) {
            false
        } finally {
            if (tmp.exists()) tmp.delete()
        }
    }
}
