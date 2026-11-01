package com.grantly.android

import android.content.Context
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

    /** Navigation labels are translated even though destination pages are not. */
    private fun selectedLanguage(): HomeLanguage {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val preferences = context.getSharedPreferences("edut_home_language", Context.MODE_PRIVATE)
        return HomeLanguage.fromCode(preferences.getString("language", "en"))
    }

    @Test fun guestProfileNavigationNeverExposesAdvisorTab() {
        val language = selectedLanguage()
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))
        assertFalse("Guest must not see the advisor-only tab",
            device.hasObject(By.text(language.navigationLabels.advisor)))

        val profile = device.wait(Until.findObject(By.text(language.labels.profile)), 15_000)
        assertNotNull("Guest should be able to open Profile", profile)
        profile!!.click()
        device.waitForIdle(5_000)
        assertFalse("Visiting Profile must not grant advisor access",
            device.hasObject(By.text(language.navigationLabels.advisor)))

        val home = device.wait(Until.findObject(By.text(language.navigationLabels.home)), 15_000)
        assertNotNull("Guest should be able to return Home", home)
        home!!.click()
        device.waitForIdle(5_000)
        assertFalse("Returning Home must not expose advisor tools",
            device.hasObject(By.text(language.navigationLabels.advisor)))
    }

    @Test fun guestCommunityRequiresSignInAndSystemBackReturnsHome() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT Home should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        // Home labels are localized, so never look up this card by its
        // English title. Its stable accessibility description belongs to the
        // clickable surface and works for all eight Home preview languages.
        // The card follows variable-length scholarship sections, so scroll
        // until it is exposed rather than assuming a fixed position.
        var community = device.wait(
            Until.findObject(By.desc("Open Community from Home")), 2_000
        )
        repeat(16) {
            if (community == null) {
                device.swipe(
                    device.displayWidth / 2, device.displayHeight * 3 / 4,
                    device.displayWidth / 2, device.displayHeight / 4, 30
                )
                community = device.wait(
                    Until.findObject(By.desc("Open Community from Home")), 1_000
                )
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
