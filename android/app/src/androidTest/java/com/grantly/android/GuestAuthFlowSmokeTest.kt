package com.grantly.android

import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Exercises only guest authentication navigation on a clean emulator.
 * Never submits credentials, sends recovery emails, or changes backend data.
 */
@RunWith(AndroidJUnit4::class)
class GuestAuthFlowSmokeTest {
    @get:Rule val composeRule = createAndroidComposeRule<MainActivity>()

    private fun togglePasswordVisibility(from: String, to: String) {
        // Compose's test action runs on the UI thread and waits for recomposition.
        // UIAutomator accessibility-node taps were intermittently dropped in CI.
        composeRule.onNodeWithContentDescription(from).assertExists().performClick()
        composeRule.onNodeWithContentDescription(to).assertExists()
    }

    @Test fun guestCanNavigateSignupAndPasswordRecovery() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        // Navigate through Compose semantics rather than an occasionally dropped
        // UIAutomator click. Both Home and bottom-nav Profile entries open sign-in.
        composeRule.onAllNodesWithText("Profile").onFirst().performClick()
        composeRule.onNodeWithText("Sign in with your existing EduT account.").assertExists()

        // Use synchronized Compose semantics for the interactive visibility control.
        togglePasswordVisibility("Show password", "Hide password")
        togglePasswordVisibility("Hide password", "Show password")

        // Compose semantics invoke the actual click actions and synchronize with
        // recomposition. UIAutomator taps on these form links were intermittently
        // dropped, even when the accessibility node was present.
        composeRule.onNodeWithText("New to EduT? Create an account")
            .assertExists().performClick()
        composeRule.onNodeWithText("Create your account").assertExists()
        composeRule.onNodeWithContentDescription("Show password").assertExists()

        composeRule.onNodeWithText("Already have an account? Sign in")
            .assertExists().performClick()
        // Sign-in-only recovery action verifies the form changed back, even if
        // its heading is outside the emulator's visible scroll viewport.
        composeRule.onNodeWithText("Forgot password?").assertExists().performClick()
        composeRule.onNodeWithText("Reset password").assertExists()
        composeRule.onNodeWithText("Back to sign in").assertExists().performClick()
        composeRule.onNodeWithText("Forgot password?").assertExists()
    }
}
