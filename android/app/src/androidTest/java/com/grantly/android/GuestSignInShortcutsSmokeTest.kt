package com.grantly.android

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Guest-only sign-in shortcut checks. No credentials are submitted and no
 * production backend records are changed. Feature parity is not implied.
 */
@RunWith(AndroidJUnit4::class)
class GuestSignInShortcutsSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    private fun deviceOnHome(): UiDevice {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))
        return device
    }

    private fun assertSignInShortcut(device: UiDevice) {
        val shortcut = device.wait(
            Until.findObject(By.text("Sign in or create account")), 15_000)
        assertNotNull("Guest destination should offer direct sign-in", shortcut)
        shortcut.click()
        assertNotNull("Shortcut should open the Profile sign-in screen",
            device.wait(Until.findObject(
                By.text("Sign in with your existing EduT account.")), 15_000))
        assertNotNull("Sign-in screen should expose email input",
            device.wait(Until.findObject(By.text("Email")), 10_000))
        assertFalse("Guest destination must close after navigating to Profile",
            device.hasObject(By.text("Sign in or create account")))
    }

    @Test fun guestNotificationsCanOpenSignInDirectly() {
        val device = deviceOnHome()
        val bell = device.wait(Until.findObject(By.desc("Open notifications")), 15_000)
        assertNotNull("Home should show notifications", bell)
        bell.click()
        assertNotNull("Notification gate should be visible",
            device.wait(Until.findObject(
                By.text("Sign in to view your notifications.")), 15_000))
        assertSignInShortcut(device)
    }

    @Test fun guestAdvisorsCanOpenSignInDirectly() {
        val device = deviceOnHome()
        val advisors = device.wait(Until.findObject(By.text("Advisors")), 15_000)
        assertNotNull("Home should show Advisors", advisors)
        advisors.click()
        assertNotNull("Advisor gate should be visible",
            device.wait(Until.findObject(
                By.text("Sign in from Profile to view approved advisors.")), 15_000))
        assertSignInShortcut(device)
    }

    @Test fun guestCommunityCanOpenSignInDirectly() {
        val device = deviceOnHome()
        var community = device.wait(Until.findObject(By.text("Explore community →")), 2_000)
        repeat(6) {
            if (community == null) {
                device.swipe(
                    device.displayWidth / 2, device.displayHeight * 3 / 4,
                    device.displayWidth / 2, device.displayHeight / 4, 30)
                community = device.wait(
                    Until.findObject(By.text("Explore community →")), 3_000)
            }
        }
        assertNotNull("Home should show Community", community)
        community!!.click()
        assertNotNull("Community gate should be visible",
            device.wait(Until.findObject(
                By.text("Sign in from the Profile tab to view community posts.")), 15_000))
        assertSignInShortcut(device)
    }
}
