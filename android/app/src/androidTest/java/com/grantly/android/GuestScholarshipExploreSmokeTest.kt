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
 * Verifies the public scholarship-discovery entry point and study-level controls.
 * Only reads public catalog data; never authenticates or changes backend records.
 */
@RunWith(AndroidJUnit4::class)
class GuestScholarshipExploreSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun guestCanOpenScholarshipSearchAndSwitchStudyLevel() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        val searchShortcut = device.wait(
            Until.findObject(By.text("Search scholarships, countries...")), 15_000)
        assertNotNull("Home should expose scholarship search", searchShortcut)
        searchShortcut.click()

        assertNotNull("Native discovery screen should open",
            device.wait(Until.findObject(By.text("Discover")), 20_000))
        assertNotNull("Search input should be available",
            device.wait(Until.findObject(By.text("Search scholarships, universities, countries")), 10_000))
        assertNotNull("Study-level filters should be available",
            device.wait(Until.findObject(By.text("Study level")), 10_000))

        val masters = device.wait(Until.findObject(By.text("Master's")), 10_000)
        assertNotNull("Master's filter should be visible", masters)
        masters.click()
        assertNotNull("Discovery should remain usable after changing filters",
            device.wait(Until.findObject(By.text("Discover")), 10_000))

        val home = device.wait(Until.findObject(By.text("Home")), 10_000)
        assertNotNull("Home navigation should remain reachable", home)
        home.click()
        assertNotNull("Home should render again",
            device.wait(Until.findObject(By.textContains("Scholarships picked")), 10_000))
    }
}
