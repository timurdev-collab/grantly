package com.grantly.android

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Guest-only navigation checks. CI uses a fresh emulator with no saved session.
 * Never submit credentials or trigger writes to the production backend.
 */
@RunWith(AndroidJUnit4::class)
class GuestAccessSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun guestMessagesAndProfileExplainHowToSignIn() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        // Advisor navigation must not be offered to a guest, even though
        // advisor discovery remains available from Home.
        assertFalse("Guest must not see the advisor-only portal tab",
            device.hasObject(By.text("Advisor")))

        val messages = device.wait(Until.findObject(By.text("Messages")), 10_000)
        assertNotNull("Messages tab should be visible", messages)
        messages.click()
        assertNotNull("Guest messages should require sign-in",
            device.wait(Until.findObject(By.text("Sign in from Profile to view your messages.")), 15_000))

        val profile = device.wait(Until.findObject(By.text("Profile")), 10_000)
        assertNotNull("Profile tab should remain reachable", profile)
        profile.click()
        assertNotNull("Guest profile should show the sign-in form",
            device.wait(Until.findObject(By.text("Welcome back")), 20_000))
        assertNotNull("Email field should be visible",
            device.wait(Until.findObject(By.text("Email")), 10_000))
        assertNotNull("Sign-in action should be visible",
            device.wait(Until.findObject(By.text("Sign in")), 10_000))
    }
}
