package com.grantly.android

import org.junit.Assert.assertThrows
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
}
