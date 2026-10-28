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
        // Use the always-visible Home shortcut rather than scrolling past
        // asynchronous recommendations. The lower Community card is covered
        // independently by GuestCommunitySmokeTest.
        val community = device.wait(Until.findObject(By.text("Community")), 15_000)
        assertNotNull("Home should show Community quick destination", community)
        community.click()
        assertNotNull("Community gate should be visible",
            device.wait(Until.findObject(
                By.text("Sign in from the Profile tab to view community posts.")), 15_000))
        assertSignInShortcut(device)
    }

    @Test fun guestApplicationsCanOpenSignInDirectly() {
        val device = deviceOnHome()
        val applications = device.wait(Until.findObject(By.text("Applications")), 15_000)
        assertNotNull("Applications destination should be visible", applications)
        applications.click()
        assertNotNull("Guest Applications should require sign-in",
            device.wait(Until.findObject(By.text(
                "Sign in on the Profile tab to see your saved scholarships.")), 15_000))
        assertSignInShortcut(device)
    }

    @Test fun guestMessagesCanOpenSignInDirectly() {
        val device = deviceOnHome()
        val messages = device.wait(Until.findObject(By.text("Messages")), 15_000)
        assertNotNull("Messages tab should be visible", messages)
        messages.click()
        assertNotNull("Guest Messages should require sign-in",
            device.wait(Until.findObject(By.text(
                "Sign in from Profile to view your messages.")), 15_000))
        assertSignInShortcut(device)
    }
}
