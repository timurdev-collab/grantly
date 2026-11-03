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
 * Launch-only smoke coverage on an Android emulator. No credentials are supplied,
 * and the test never performs authenticated or production-backend mutations.
 */
@RunWith(AndroidJUnit4::class)
class MainActivitySmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun systemBackFromExploreReturnsHomeWithoutExiting() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 45_000))

        val explore = device.wait(Until.findObject(By.text("Explore")), 15_000)
        assertNotNull("Explore tab should be available", explore)
        explore.click()
        assertNotNull("Explore destination should open",
            device.wait(Until.findObject(By.text("Discover")), 15_000))

        device.pressBack()
        assertNotNull("System Back should return to Home",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 15_000))
        assertNotNull("Activity should remain open with primary navigation",
            device.wait(Until.findObject(By.text("Explore")), 10_000))
    }

    @Test fun systemBackFromApplicationsReturnsHomeWithoutExiting() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 45_000))

        val applications = device.wait(Until.findObject(By.text("Applications")), 15_000)
        assertNotNull("Applications tab should be available", applications)
        applications.click()
        assertNotNull("Applications should retain the EduT app shell",
            device.wait(Until.findObject(By.text("EduT")), 15_000))

        device.pressBack()
        assertNotNull("System Back should return to Home from Applications",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 15_000))
        assertNotNull("Activity should remain open with primary navigation",
            device.wait(Until.findObject(By.text("Applications")), 10_000))
    }

    @Test fun systemBackFromMessagesReturnsHomeWithoutExiting() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 45_000))

        val messages = device.wait(Until.findObject(By.text("Messages")), 15_000)
        assertNotNull("Messages tab should be available", messages)
        messages.click()
        assertNotNull("Messages should retain the EduT app shell",
            device.wait(Until.findObject(By.text("EduT")), 15_000))

        device.pressBack()
        assertNotNull("System Back should return to Home from Messages",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 15_000))
        assertNotNull("Activity should remain open with primary navigation",
            device.wait(Until.findObject(By.text("Messages")), 10_000))
    }

    @Test fun homeOpensAndPrimaryNavigationRemainsUsable() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        // A cold API-35 emulator may take longer to expose Compose semantics.
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should render", device.wait(Until.findObject(By.text("EduT")), 45_000))
        val explore = device.wait(Until.findObject(By.text("Explore")), 10_000)
        assertNotNull("Explore tab should be visible", explore)
        explore.click()
        assertNotNull("Explore should retain the EduT app shell",
            device.wait(Until.findObject(By.text("EduT")), 10_000))
        val home = device.wait(Until.findObject(By.text("Home")), 10_000)
        assertNotNull("Home tab should remain reachable", home)
        home.click()
        assertNotNull("Home should render after switching tabs",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 10_000))
    }
}
