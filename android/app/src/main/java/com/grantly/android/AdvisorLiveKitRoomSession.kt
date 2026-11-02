package com.grantly.android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import io.livekit.android.LiveKit
import io.livekit.android.room.Room
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.sync.Mutex
import java.io.IOException
import java.util.concurrent.atomic.AtomicLong

/**
 * LiveKit connection lifecycle for an EXISTING advisor call.
 *
 * The call screen must obtain explicit capture consent and OS permissions,
 * and invoke leave() on navigation, sign-out, or Activity teardown.
 * No recording is enabled here. Authenticated device calls are not verified.
 */
internal object AdvisorLiveKitRoomRules {
    fun shouldInvalidatePendingJoin(pendingUserId: String?, currentUserId: String?): Boolean =
        pendingUserId != null && pendingUserId != currentUserId

    /** An active room must invalidate in-flight media toggles before waiting for the mutex. */
    fun shouldInvalidateRoomForAccountChange(
        pendingUserId: String?, activeUserId: String?, currentUserId: String?
    ): Boolean = shouldInvalidatePendingJoin(pendingUserId, currentUserId) ||
        shouldInvalidatePendingJoin(activeUserId, currentUserId)

    /** A session may change while a LiveKit media toggle is suspended. */
    fun shouldDisableCaptureAfterMediaChange(
        requestedGeneration: Long,
        currentGeneration: Long,
        expectedUserId: String,
        currentUserId: String?,
        permissionGranted: Boolean = true
    ): Boolean = requestedGeneration != currentGeneration ||
        expectedUserId != currentUserId || !permissionGranted

    fun requireNotLeft(joinGeneration: Long, currentGeneration: Long) {
        if (joinGeneration != currentGeneration) {
            throw IOException("The video call was closed before it could connect.")
        }
    }

    /** Bound credential retrieval and LiveKit connection attempts to avoid an
     * indefinite spinner when a network request never completes. The caller's
     * own cancellation is preserved; only this timeout becomes a retryable error.
     */
    suspend fun <T> withJoinTimeout(
        timeoutMillis: Long = 30_000L,
        operation: suspend () -> T
    ): T = try {
        withTimeout(timeoutMillis) { operation() }
    } catch (_: TimeoutCancellationException) {
        // An enclosing screen/job timeout must remain cancellation, not a
        // retryable network error. Only our own timeout is converted.
        currentCoroutineContext().ensureActive()
        throw IOException("The video call connection timed out. Please try again.")
    }

    /** Bound a suspended SDK media toggle so it cannot indefinitely hold the
     * room mutex and prevent Leave from cleaning up the call. Caller-initiated
     * cancellation must still propagate to the capture rollback handler.
     */
    suspend fun <T> withMediaTimeout(
        timeoutMillis: Long = 30_000L,
        operation: suspend () -> T
    ): T = try {
        withTimeout(timeoutMillis) { operation() }
    } catch (_: TimeoutCancellationException) {
        currentCoroutineContext().ensureActive()
        throw IOException("Camera or microphone operation timed out. Please leave the call and try again.")
    }

    /**
     * LiveKit may have enabled hardware capture before a suspended SDK call
     * fails or is cancelled. Always attempt a bounded rollback before returning
     * the original failure; this also covers cancellation during Join/media UI
     * teardown, when the caller's coroutine is no longer active.
     */
    suspend fun withCaptureRollbackOnFailure(
        enabling: Boolean,
        operation: suspend () -> Unit,
        rollback: suspend () -> Unit
    ) {
        try {
            operation()
        } catch (failure: Throwable) {
            if (enabling) {
                withContext(NonCancellable) {
                    try {
                        withTimeout(5_000L) { rollback() }
                    } catch (rollbackFailure: Throwable) {
                        if (rollbackFailure !== failure) failure.addSuppressed(rollbackFailure)
                    }
                }
            }
            throw failure
        }
    }

    /**
     * Initial Join can fail after one or both LiveKit capture calls have
     * started. Disable every attempted track, even if disabling video fails.
     * Each track gets its own timeout so a hung video rollback does not skip
     * microphone cleanup.
     */
    suspend fun rollbackInitialCapture(
        microphoneAttempted: Boolean,
        cameraAttempted: Boolean,
        disableMicrophone: suspend () -> Unit,
        disableCamera: suspend () -> Unit
    ) {
        try {
            if (cameraAttempted) withTimeout(2_000L) { disableCamera() }
        } finally {
            if (microphoneAttempted) withTimeout(2_000L) { disableMicrophone() }
        }
    }

    fun requireCaptureReady(
        captureConsent: Boolean,
        microphoneGranted: Boolean,
        cameraGranted: Boolean
    ) {
        if (!captureConsent) {
            throw IOException("Camera and microphone must be explicitly enabled before joining.")
        }
        if (!microphoneGranted || !cameraGranted) {
            throw IOException("Camera and microphone permissions are required for this video call.")
        }
    }

    /** Muting is always allowed while the current account owns the room.
     * Re-enabling capture additionally requires the relevant OS permission.
     */
    fun requireMediaChangeAuthorized(
        requestedGeneration: Long,
        currentGeneration: Long,
        expectedUserId: String,
        activeUserId: String?,
        currentUserId: String?,
        enabling: Boolean,
        permissionGranted: Boolean
    ) {
        requireNotLeft(requestedGeneration, currentGeneration)
        AdvisorCallPreparationRules.requireSameAccount(expectedUserId, activeUserId)
        AdvisorCallPreparationRules.requireSameAccount(expectedUserId, currentUserId)
        if (enabling && !permissionGranted) {
            throw IOException("Media permission was revoked. Leave the call and grant it again.")
        }
    }

    /**
     * Permissions or the signed-in account may change while credentials and the
     * LiveKit connection are loading. Recheck immediately before each capture
     * transition, not only when Join was first tapped.
     */
    fun requireCaptureStillAuthorized(
        joinGeneration: Long,
        currentGeneration: Long,
        expectedUserId: String,
        currentUserId: String?,
        captureConsent: Boolean,
        microphoneGranted: Boolean,
        cameraGranted: Boolean
    ) {
        requireNotLeft(joinGeneration, currentGeneration)
        AdvisorCallPreparationRules.requireSameAccount(expectedUserId, currentUserId)
        requireCaptureReady(captureConsent, microphoneGranted, cameraGranted)
    }
}

/**
 * Owns at most one Room. Never reuses a released Room across calls.
 * Access is serialized, including a slow or cancelled connection attempt.
 */
internal class AdvisorLiveKitRoomSession(private val context: Context) {
    private val lock = Mutex()
    // A Leave action must invalidate an in-flight connect BEFORE waiting for the
    // mutex: otherwise a slow connection could start capture after the user left.
    private val leaveGeneration = AtomicLong(0)
    // Visible to account-change callbacks while a slow join holds the mutex.
    @Volatile private var pendingJoinUserId: String? = null
    private var activeRoom: Room? = null
    @Volatile private var activeUserId: String? = null

    suspend fun joinExistingCall(
        callId: String,
        expectedUserId: String,
        captureConsent: Boolean
    ): Room {
        val joinGeneration = leaveGeneration.get()
        lock.lock()
        try {
            requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
            if (activeRoom != null) throw IOException("A video call is already in progress.")
            pendingJoinUserId = expectedUserId

            // Fetch only for a pre-existing, currently authorized call session.
            val credentials = AdvisorLiveKitRoomRules.withJoinTimeout {
                AdvisorCallPreparationRepository.credentialsForExistingCall(callId, expectedUserId)
            }
            AdvisorCallPreparationRules.requireSameAccount(
                expectedUserId, AuthRepository.session?.userId
            )

            AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration, leaveGeneration.get())
            val room = LiveKit.create(context.applicationContext)
            try {
                AdvisorLiveKitRoomRules.withJoinTimeout {
                    room.connect(credentials.url, credentials.token)
                }
                // A user can revoke permissions or switch accounts during a
                // slow connection. Recheck before BOTH media operations.
                // A failed, cancelled or timed-out initial capture enable can
                // leave a track running before the Room is disconnected. Roll
                // back both attempted tracks before releasing the Room.
                var microphoneAttempted = false
                var cameraAttempted = false
                AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                    enabling = true,
                    operation = {
                        AdvisorLiveKitRoomRules.withJoinTimeout {
                            requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
                            microphoneAttempted = true
                            room.localParticipant.setMicrophoneEnabled(true)
                            requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
                            cameraAttempted = true
                            room.localParticipant.setCameraEnabled(true)
                            requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
                        }
                    },
                    rollback = {
                        AdvisorLiveKitRoomRules.rollbackInitialCapture(
                            microphoneAttempted = microphoneAttempted,
                            cameraAttempted = cameraAttempted,
                            disableMicrophone = { room.localParticipant.setMicrophoneEnabled(false) },
                            disableCamera = { room.localParticipant.setCameraEnabled(false) }
                        )
                    }
                )
                activeRoom = room
                activeUserId = expectedUserId
                return room
            } catch (failure: Throwable) {
                // A timeout/cancelled Join must still release the Room even if
                // its coroutine is already cancelled.
                withContext(NonCancellable) {
                    try {
                        room.disconnect()
                    } finally {
                        room.release()
                    }
                }
                throw failure
            }
        } finally {
            pendingJoinUserId = null
            lock.unlock()
        }
    }

    private fun requireCaptureStillAuthorized(
        joinGeneration: Long,
        expectedUserId: String,
        captureConsent: Boolean
    ) {
        AdvisorLiveKitRoomRules.requireCaptureStillAuthorized(
            joinGeneration = joinGeneration,
            currentGeneration = leaveGeneration.get(),
            expectedUserId = expectedUserId,
            currentUserId = AuthRepository.session?.userId,
            captureConsent = captureConsent,
            microphoneGranted = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED,
            cameraGranted = context.checkSelfPermission(Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        )
    }

    /** Media toggles are serialized with Leave and never act on a released room. */
    suspend fun setMicrophoneEnabled(expectedUserId: String, enabled: Boolean) {
        setMediaEnabled(expectedUserId, microphone = true, enabled = enabled)
    }

    suspend fun setCameraEnabled(expectedUserId: String, enabled: Boolean) {
        setMediaEnabled(expectedUserId, microphone = false, enabled = enabled)
    }

    private suspend fun setMediaEnabled(expectedUserId: String, microphone: Boolean, enabled: Boolean) {
        val requestedGeneration = leaveGeneration.get()
        lock.lock()
        try {
            val room = activeRoom ?: throw IOException("The call has already ended.")
            val permission = if (microphone) Manifest.permission.RECORD_AUDIO else Manifest.permission.CAMERA
            AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                requestedGeneration = requestedGeneration,
                currentGeneration = leaveGeneration.get(),
                expectedUserId = expectedUserId,
                activeUserId = activeUserId,
                currentUserId = AuthRepository.session?.userId,
                enabling = enabled,
                permissionGranted = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
            )
            // Keep the post-SDK account, Leave, and permission checks INSIDE
            // the rollback boundary. Otherwise a revoked permission could make
            // the explicit disable fail or be cancelled, leaving capture active.
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = enabled,
                operation = {
                    AdvisorLiveKitRoomRules.withMediaTimeout {
                        if (microphone) room.localParticipant.setMicrophoneEnabled(enabled)
                        else room.localParticipant.setCameraEnabled(enabled)
                        // A suspended SDK call can outlive permission or account
                        // changes. Keep this check inside the timeout/rollback.
                        AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                            requestedGeneration = requestedGeneration,
                            currentGeneration = leaveGeneration.get(),
                            expectedUserId = expectedUserId,
                            activeUserId = activeUserId,
                            currentUserId = AuthRepository.session?.userId,
                            enabling = enabled,
                            permissionGranted = context.checkSelfPermission(permission) ==
                                PackageManager.PERMISSION_GRANTED
                        )
                    }
                },
                rollback = {
                    if (microphone) room.localParticipant.setMicrophoneEnabled(false)
                    else room.localParticipant.setCameraEnabled(false)
                }
            )
        } finally {
            lock.unlock()
        }
    }

    /**
     * Call synchronously from Back or ON_STOP before scheduling coroutine cleanup.
     * This invalidates an in-flight Join even when the UI coroutine cannot run yet.
     * Always follow with leave() to disconnect and release the room.
     */
    fun invalidatePendingJoin() {
        leaveGeneration.incrementAndGet()
    }

    /** Call on Back, navigation away, sign-out, and lifecycle teardown. */
    suspend fun leave() {
        // Invalidate a pending join immediately, even while it owns the mutex.
        invalidatePendingJoin()
        lock.lock()
        try {
            val room = activeRoom
            activeRoom = null
            activeUserId = null
            if (room != null) {
                try {
                    room.disconnect()
                } finally {
                    room.release()
                }
            }
        } finally {
            lock.unlock()
        }
    }

    /** Caller must invoke this when the authenticated account changes. */
    suspend fun leaveIfAccountChanged() {
        // Invalidate an in-flight join BEFORE waiting for its mutex. Otherwise a
        // slow LiveKit connection can start capture after account switching.
        if (AdvisorLiveKitRoomRules.shouldInvalidateRoomForAccountChange(
                pendingJoinUserId, activeUserId, AuthRepository.session?.userId
            )) {
            leaveGeneration.incrementAndGet()
        }
        lock.lock()
        try {
            val userId = activeUserId
            if (userId != null && userId != AuthRepository.session?.userId) {
                val room = activeRoom
                activeRoom = null
                activeUserId = null
                if (room != null) {
                    try {
                        room.disconnect()
                    } finally {
                        room.release()
                    }
                }
            }
        } finally {
            lock.unlock()
        }
    }
}
