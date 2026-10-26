package com.grantly.android

import androidx.test.ext.junit.rules.ActivityScenarioRule
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
 * Checks iOS-style Home quick destinations without credentials or backend mutations.
 * The emulator is a guest; this verifies navigation, not application functionality.
 */
@RunWith(AndroidJUnit4::class)
class HomeQuickDestinationsSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun homeQuickDestinationsOpenExploreAndApplications() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        val forYou = device.wait(Until.findObject(By.text("For you")), 10_000)
        assertNotNull("Home should expose For you", forYou)
        forYou.click()
        assertNotNull("For you should open Discover",
            device.wait(Until.findObject(By.text("Discover")), 20_000))

        val home = device.wait(Until.findObject(By.text("Home")), 10_000)
        assertNotNull("Home tab should be reachable", home)
        home.click()
        assertNotNull("Home should show quick destinations again",
            device.wait(Until.findObject(By.text("For you")), 10_000))

        val applications = device.wait(Until.findObject(By.text("Applications")), 10_000)
        assertNotNull("Applications shortcut should be visible", applications)
        applications.click()
        assertNotNull("Guest applications should explain sign-in",
            device.wait(Until.findObject(By.text("Sign in on the Profile tab to see your saved scholarships.")), 15_000))
    }
}
