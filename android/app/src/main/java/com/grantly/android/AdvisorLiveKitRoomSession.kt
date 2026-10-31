package com.grantly.android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import io.livekit.android.LiveKit
import io.livekit.android.room.Room
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

    fun requireNotLeft(joinGeneration: Long, currentGeneration: Long) {
        if (joinGeneration != currentGeneration) {
            throw IOException("The video call was closed before it could connect.")
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
    private var activeUserId: String? = null

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
            val credentials = AdvisorCallPreparationRepository.credentialsForExistingCall(
                callId, expectedUserId
            )
            AdvisorCallPreparationRules.requireSameAccount(
                expectedUserId, AuthRepository.session?.userId
            )

            AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration, leaveGeneration.get())
            val room = LiveKit.create(context.applicationContext)
            try {
                room.connect(credentials.url, credentials.token)
                // A user can revoke permissions or switch accounts during a
                // slow connection. Recheck before BOTH media operations.
                requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
                room.localParticipant.setMicrophoneEnabled(true)
                requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
                room.localParticipant.setCameraEnabled(true)
                requireCaptureStillAuthorized(joinGeneration, expectedUserId, captureConsent)
                activeRoom = room
                activeUserId = expectedUserId
                return room
            } catch (failure: Throwable) {
                try {
                    room.disconnect()
                } finally {
                    room.release()
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
            if (microphone) {
                room.localParticipant.setMicrophoneEnabled(enabled)
            } else {
                room.localParticipant.setCameraEnabled(enabled)
            }
            // Leave can invalidate a media operation while LiveKit is suspending.
            // Turn capture back off before returning control to the waiting Leave.
            if (enabled && requestedGeneration != leaveGeneration.get()) {
                if (microphone) room.localParticipant.setMicrophoneEnabled(false)
                else room.localParticipant.setCameraEnabled(false)
            }
            AdvisorLiveKitRoomRules.requireNotLeft(requestedGeneration, leaveGeneration.get())
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
        if (AdvisorLiveKitRoomRules.shouldInvalidatePendingJoin(
                pendingJoinUserId, AuthRepository.session?.userId
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
