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
 * Guest-only Home navigation checks. The emulator has no saved session.
 * Never authenticate, request bookings, or mutate the production backend.
 * These tests verify access gates and navigation, not live account behavior.
 */
@RunWith(AndroidJUnit4::class)
class GuestHomeDestinationsSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun notificationBellOpensGuestInboxAndReturnsHome() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        val bell = device.wait(Until.findObject(By.desc("Open notifications")), 15_000)
        assertNotNull("Home notification bell should be accessible", bell)
        bell.click()

        assertNotNull("Notification inbox should open",
            device.wait(Until.findObject(By.text("Notifications")), 15_000))
        assertNotNull("Guest inbox should require sign-in",
            device.wait(Until.findObject(By.text("Sign in to view your notifications.")), 15_000))

        val back = device.wait(Until.findObject(By.text("← Back to Home")), 10_000)
        assertNotNull("Guest notification inbox should provide Back to Home", back)
        back.click()
        assertNotNull("Home search should reappear",
            device.wait(Until.findObject(By.text("Search scholarships, countries...")), 15_000))
    }

    @Test fun advisorShortcutShowsGuestSignInGate() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        val advisors = device.wait(Until.findObject(By.text("Advisors")), 15_000)
        assertNotNull("Home should expose the Advisors shortcut", advisors)
        advisors.click()

        assertNotNull("Advisor directory should open",
            device.wait(Until.findObject(By.text("Find an advisor")), 15_000))
        assertNotNull("Guest directory should require sign-in",
            device.wait(Until.findObject(By.text("Sign in from Profile to view approved advisors.")), 15_000))
    }
}
