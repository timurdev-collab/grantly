package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Test
import java.io.IOException

class AdvisorLiveKitRoomRulesTest {
    @Test fun invalidatesPendingJoinForSwitchedAccountOrSignOut() {
        for (current in listOf("student-2", null)) {
            org.junit.Assert.assertTrue(
                AdvisorLiveKitRoomRules.shouldInvalidatePendingJoin("advisor-1", current)
            )
        }
    }

    @Test fun invalidatesActiveRoomMediaWhenAccountSwitchesOrSignsOut() {
        for (current in listOf("student-2", null)) {
            org.junit.Assert.assertTrue(
                AdvisorLiveKitRoomRules.shouldInvalidateRoomForAccountChange(
                    pendingUserId = null, activeUserId = "advisor-1", currentUserId = current
                )
            )
        }
    }

    @Test fun preservesActiveRoomWhenAccountIsUnchangedOrNoRoomExists() {
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldInvalidateRoomForAccountChange(null, "advisor-1", "advisor-1")
        )
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldInvalidateRoomForAccountChange(null, null, null)
        )
        org.junit.Assert.assertTrue(
            AdvisorLiveKitRoomRules.shouldInvalidateRoomForAccountChange("advisor-1", null, null)
        )
    }

    @Test fun preservesPendingJoinForSameAccountAndNoPendingJoin() {
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldInvalidatePendingJoin("advisor-1", "advisor-1")
        )
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldInvalidatePendingJoin(null, "advisor-1")
        )
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldInvalidatePendingJoin(null, null)
        )
    }

    @Test fun disablesCaptureAfterAccountSwitchEvenWithoutLeaveCallback() {
        for (current in listOf("student-2", null)) {
            org.junit.Assert.assertTrue(
                AdvisorLiveKitRoomRules.shouldDisableCaptureAfterMediaChange(
                    requestedGeneration = 11, currentGeneration = 11,
                    expectedUserId = "advisor-1", currentUserId = current
                )
            )
        }
    }

    @Test fun disablesCaptureWhenPermissionRevokedDuringSuspendedEnable() {
        // The initial permission preflight can pass, then the user can revoke
        // access while LiveKit is enabling the camera or microphone.
        org.junit.Assert.assertTrue(
            AdvisorLiveKitRoomRules.shouldDisableCaptureAfterMediaChange(
                requestedGeneration = 11,
                currentGeneration = 11,
                expectedUserId = "advisor-1",
                currentUserId = "advisor-1",
                permissionGranted = false
            )
        )
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldDisableCaptureAfterMediaChange(
                requestedGeneration = 11,
                currentGeneration = 11,
                expectedUserId = "advisor-1",
                currentUserId = "advisor-1",
                permissionGranted = true
            )
        )
        assertThrows(IOException::class.java) {
            AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                requestedGeneration = 11,
                currentGeneration = 11,
                expectedUserId = "advisor-1",
                activeUserId = "advisor-1",
                currentUserId = "advisor-1",
                enabling = true,
                permissionGranted = false
            )
        }
    }

    @Test fun disablesCaptureAfterLeaveAndPreservesCurrentAccountMedia() {
        org.junit.Assert.assertTrue(
            AdvisorLiveKitRoomRules.shouldDisableCaptureAfterMediaChange(
                11, 12, "advisor-1", "advisor-1"
            )
        )
        org.junit.Assert.assertFalse(
            AdvisorLiveKitRoomRules.shouldDisableCaptureAfterMediaChange(
                11, 11, "advisor-1", "advisor-1"
            )
        )
    }

    @Test fun allowsJoinWhenNoLeaveWasRequested() {
        AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration = 4, currentGeneration = 4)
    }

    @Test fun rejectsStaleJoinAfterLeaveOrNavigationAway() {
        assertThrows(IOException::class.java) {
            AdvisorLiveKitRoomRules.requireNotLeft(joinGeneration = 4, currentGeneration = 5)
        }
    }

    @Test fun allowsExplicitConsentWithBothCapturePermissions() {
        AdvisorLiveKitRoomRules.requireCaptureReady(
            captureConsent = true,
            microphoneGranted = true,
            cameraGranted = true
        )
    }

    @Test fun rejectsMissingConsentEvenWhenPermissionsExist() {
        assertThrows(IOException::class.java) {
            AdvisorLiveKitRoomRules.requireCaptureReady(
                captureConsent = false,
                microphoneGranted = true,
                cameraGranted = true
            )
        }
    }

    @Test fun allowsCaptureOnlyForCurrentAccountWithFreshPermissions() {
        AdvisorLiveKitRoomRules.requireCaptureStillAuthorized(
            joinGeneration = 8,
            currentGeneration = 8,
            expectedUserId = "advisor-1",
            currentUserId = "advisor-1",
            captureConsent = true,
            microphoneGranted = true,
            cameraGranted = true
        )
    }

    @Test fun rejectsAccountSwitchOrSignOutBeforeMediaCapture() {
        for (current in listOf("advisor-2", null)) {
            assertThrows(IOException::class.java) {
                AdvisorLiveKitRoomRules.requireCaptureStillAuthorized(
                    joinGeneration = 8,
                    currentGeneration = 8,
                    expectedUserId = "advisor-1",
                    currentUserId = current,
                    captureConsent = true,
                    microphoneGranted = true,
                    cameraGranted = true
                )
            }
        }
    }

    @Test fun rejectsPermissionsRevokedDuringConnection() {
        for ((mic, camera) in listOf(false to true, true to false)) {
            assertThrows(IOException::class.java) {
                AdvisorLiveKitRoomRules.requireCaptureStillAuthorized(
                    joinGeneration = 8,
                    currentGeneration = 8,
                    expectedUserId = "advisor-1",
                    currentUserId = "advisor-1",
                    captureConsent = true,
                    microphoneGranted = mic,
                    cameraGranted = camera
                )
            }
        }
    }

    @Test fun rejectsLeaveRequestedDuringConnectionEvenWithPermissions() {
        assertThrows(IOException::class.java) {
            AdvisorLiveKitRoomRules.requireCaptureStillAuthorized(
                joinGeneration = 8,
                currentGeneration = 9,
                expectedUserId = "advisor-1",
                currentUserId = "advisor-1",
                captureConsent = true,
                microphoneGranted = true,
                cameraGranted = true
            )
        }
    }

    @Test fun rejectsMissingMicrophoneOrCameraPermission() {
        for (microphoneGranted in listOf(false, true)) {
            for (cameraGranted in listOf(false, true)) {
                if (microphoneGranted && cameraGranted) continue
                assertThrows(IOException::class.java) {
                    AdvisorLiveKitRoomRules.requireCaptureReady(
                        captureConsent = true,
                        microphoneGranted = microphoneGranted,
                        cameraGranted = cameraGranted
                    )
                }
            }
        }
    }

    @Test fun allowsMutingWithoutCapturePermission() {
        AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
            requestedGeneration = 11,
            currentGeneration = 11,
            expectedUserId = "advisor-1",
            activeUserId = "advisor-1",
            currentUserId = "advisor-1",
            enabling = false,
            permissionGranted = false
        )
    }

    @Test fun allowsUnmutingWithPermissionAndSameAccount() {
        AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
            requestedGeneration = 11,
            currentGeneration = 11,
            expectedUserId = "advisor-1",
            activeUserId = "advisor-1",
            currentUserId = "advisor-1",
            enabling = true,
            permissionGranted = true
        )
    }

    @Test fun rejectsUnmutingAfterPermissionRevocation() {
        assertThrows(IOException::class.java) {
            AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                requestedGeneration = 11,
                currentGeneration = 11,
                expectedUserId = "advisor-1",
                activeUserId = "advisor-1",
                currentUserId = "advisor-1",
                enabling = true,
                permissionGranted = false
            )
        }
    }

    @Test fun rejectsMediaChangesAfterLeaveOrAccountChange() {
        val invalid = listOf(
            Triple(12L, "advisor-1", "advisor-1"),
            Triple(11L, "advisor-2", "advisor-1"),
            Triple(11L, "advisor-1", null)
        )
        for ((generation, active, signedIn) in invalid) {
            assertThrows(IOException::class.java) {
                AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                    requestedGeneration = 11,
                    currentGeneration = generation,
                    expectedUserId = "advisor-1",
                    activeUserId = active,
                    currentUserId = signedIn,
                    enabling = false,
                    permissionGranted = true
                )
            }
        }
    }
    @Test fun boundedJoinReturnsNormallyWhenNetworkCompletes() = runBlocking {
        assertEquals("connected", AdvisorLiveKitRoomRules.withJoinTimeout(1_000L) {
            "connected"
        })
    }

    @Test fun boundedJoinTurnsTimeoutIntoRetryableError() = runBlocking {
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withJoinTimeout(10L) { delay(1_000L) }
        }.exceptionOrNull()
        assertTrue(failure is IOException)
        assertTrue(failure?.message?.contains("timed out") == true)
    }

    @Test fun boundedJoinDoesNotMaskEnclosingTimeout() = runBlocking {
        // The parent may cancel a join before its 30-second network limit.
        // This must propagate cancellation, not become a retryable IOException.
        val failure = runCatching {
            withTimeout(20L) {
                AdvisorLiveKitRoomRules.withJoinTimeout(30_000L) {
                    delay(1_000L)
                }
            }
        }.exceptionOrNull()
        assertTrue("Parent cancellation must not be converted to IOException",
            failure is TimeoutCancellationException)
    }

    @Test fun boundedJoinPreservesCallerCancellation() = runBlocking {
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withJoinTimeout(1_000L) {
                throw CancellationException("Call screen closed")
            }
        }.exceptionOrNull()
        assertTrue(failure is CancellationException)
    }

    @Test fun captureEnableFailureRollsBackAndPreservesOriginalError() = runBlocking {
        val original = IOException("SDK failed after enabling")
        var rollbackCount = 0
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = true,
                operation = { throw original },
                rollback = { rollbackCount++ }
            )
        }.exceptionOrNull()
        assertTrue(failure === original)
        assertEquals(1, rollbackCount)
    }

    @Test fun cancelledCaptureEnableStillRollsBack() = runBlocking {
        var rollbackCount = 0
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = true,
                operation = { throw CancellationException("Screen closed") },
                rollback = { rollbackCount++ }
            )
        }.exceptionOrNull()
        assertTrue(failure is CancellationException)
        assertEquals(1, rollbackCount)
    }

    @Test fun successfulCaptureAndFailedDisableDoNotTriggerRollback() = runBlocking {
        var operations = 0
        var rollbacks = 0
        AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
            enabling = true,
            operation = { operations++ },
            rollback = { rollbacks++ }
        )
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = false,
                operation = { throw IOException("Mute failed") },
                rollback = { rollbacks++ }
            )
        }.exceptionOrNull()
        assertTrue(failure is IOException)
        assertEquals(1, operations)
        assertEquals(0, rollbacks)
    }

    @Test fun rollbackFailureIsSuppressedWithoutMaskingEnableFailure() = runBlocking {
        val original = IOException("Enable failed")
        val rollback = IOException("Rollback failed")
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = true,
                operation = { throw original },
                rollback = { throw rollback }
            )
        }.exceptionOrNull()
        assertTrue(failure is IOException)
        assertEquals("Enable failed", failure?.message)
        assertTrue("Rollback error should be retained for diagnostics",
            failure?.suppressed?.any { it.message == "Rollback failed" } == true)
    }


    @Test fun permissionRevokedAfterSdkEnableStillRollsBack() = runBlocking {
        var captureEnabled = false
        var rollbackCount = 0
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = true,
                operation = {
                    // LiveKit completed enabling capture, but Android permission
                    // was revoked while the SDK call was suspended.
                    captureEnabled = true
                    AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                        requestedGeneration = 11,
                        currentGeneration = 11,
                        expectedUserId = "advisor-1",
                        activeUserId = "advisor-1",
                        currentUserId = "advisor-1",
                        enabling = true,
                        permissionGranted = false
                    )
                },
                rollback = {
                    captureEnabled = false
                    rollbackCount++
                }
            )
        }.exceptionOrNull()
        assertTrue(failure is IOException)
        assertTrue(failure?.message?.contains("permission was revoked") == true)
        assertEquals(1, rollbackCount)
        org.junit.Assert.assertFalse(captureEnabled)
    }

    @Test fun leaveDuringSdkEnableStillRollsBack() = runBlocking {
        var captureEnabled = false
        var rollbackCount = 0
        val failure = runCatching {
            AdvisorLiveKitRoomRules.withCaptureRollbackOnFailure(
                enabling = true,
                operation = {
                    captureEnabled = true
                    AdvisorLiveKitRoomRules.requireMediaChangeAuthorized(
                        requestedGeneration = 11,
                        currentGeneration = 12,
                        expectedUserId = "advisor-1",
                        activeUserId = "advisor-1",
                        currentUserId = "advisor-1",
                        enabling = true,
                        permissionGranted = true
                    )
                },
                rollback = {
                    captureEnabled = false
                    rollbackCount++
                }
            )
        }.exceptionOrNull()
        assertTrue(failure is IOException)
        assertEquals(1, rollbackCount)
        org.junit.Assert.assertFalse(captureEnabled)
    }
}
