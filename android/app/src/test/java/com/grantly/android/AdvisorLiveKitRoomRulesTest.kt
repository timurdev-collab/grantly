package com.grantly.android

import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException

class AdvisorLiveKitRoomRulesTest {
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
