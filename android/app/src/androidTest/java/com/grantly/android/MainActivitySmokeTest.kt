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

    @Test fun homeOpensAndPrimaryNavigationRemainsUsable() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        assertNotNull("EduT Home should render", device.wait(Until.findObject(By.text("EduT")), 20_000))
        val explore = device.wait(Until.findObject(By.text("Explore")), 10_000)
        assertNotNull("Explore tab should be visible", explore)
        explore.click()
        assertNotNull("Explore should retain the EduT app shell",
            device.wait(Until.findObject(By.text("EduT")), 10_000))
        val home = device.wait(Until.findObject(By.text("Home")), 10_000)
        assertNotNull("Home tab should remain reachable", home)
        home.click()
        assertNotNull("Home should render after switching tabs",
            device.wait(Until.findObject(By.text("Scholarships picked\nfor your next chapter.")), 10_000))
    }
}
