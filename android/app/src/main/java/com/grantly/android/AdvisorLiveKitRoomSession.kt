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
 * Source-only LiveKit connection lifecycle for an EXISTING advisor call.
 *
 * Not wired to a Join button. The caller must obtain explicit capture consent,
 * request Android camera/microphone permissions, and call leave() on navigation
 * away, sign-out, or Activity teardown. No recording is enabled here.
 */
internal object AdvisorLiveKitRoomRules {
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
            AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration, leaveGeneration.get())
            AdvisorLiveKitRoomRules.requireCaptureReady(
                captureConsent,
                context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                    PackageManager.PERMISSION_GRANTED,
                context.checkSelfPermission(Manifest.permission.CAMERA) ==
                    PackageManager.PERMISSION_GRANTED
            )
            AdvisorCallPreparationRules.requireSameAccount(
                expectedUserId, AuthRepository.session?.userId
            )
            if (activeRoom != null) throw IOException("A video call is already in progress.")

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
                AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration, leaveGeneration.get())
                AdvisorCallPreparationRules.requireSameAccount(
                    expectedUserId, AuthRepository.session?.userId
                )
                // Never begin capture after a Leave request during a slow connect.
                room.localParticipant.setMicrophoneEnabled(true)
                AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration, leaveGeneration.get())
                room.localParticipant.setCameraEnabled(true)
                AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration, leaveGeneration.get())
                AdvisorCallPreparationRules.requireSameAccount(
                    expectedUserId, AuthRepository.session?.userId
                )
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
            lock.unlock()
        }
    }

    /** Call on Back, navigation away, sign-out, and lifecycle teardown. */
    suspend fun leave() {
        // Invalidate a pending join immediately, even while it owns the mutex.
        leaveGeneration.incrementAndGet()
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
