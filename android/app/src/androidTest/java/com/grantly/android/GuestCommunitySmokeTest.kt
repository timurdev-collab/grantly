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
 * Guest-only Community access regression test.
 * Never signs in, uploads media, or writes to the production backend.
 * Validates that guest users see the sign-in gate and cannot open the composer.
 */
@RunWith(AndroidJUnit4::class)
class GuestCommunitySmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun guestCommunityRequiresSignInAndSystemBackReturnsHome() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        // The Community card is below the Home recommendations on smaller devices.
        // Scroll the Home content rather than assuming the card is initially visible.
        var community = device.wait(Until.findObject(By.text("Explore community →")), 2_000)
        repeat(6) {
            if (community == null) {
                device.swipe(
                    device.displayWidth / 2, device.displayHeight * 3 / 4,
                    device.displayWidth / 2, device.displayHeight / 4, 30
                )
                community = device.wait(Until.findObject(By.text("Explore community →")), 3_000)
            }
        }
        assertNotNull("Home should expose Community navigation", community)
        community!!.click()

        assertNotNull("Community should explain guest access",
            device.wait(Until.findObject(By.text(
                "Sign in from the Profile tab to view community posts."
            )), 15_000))
        assertFalse("Guest users must not see the Community post composer",
            device.hasObject(By.text("Create post")))

        device.pressBack()
        assertNotNull("System Back should return to Home",
            device.wait(Until.findObject(By.text("EduT")), 15_000))
        assertFalse("Guest Community gate should close after Back",
            device.hasObject(By.text("Sign in from the Profile tab to view community posts.")))
    }
}
