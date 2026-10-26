package com.grantly.android

import android.content.Intent
import android.net.Uri
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Checks that an incomplete recovery deep link opens Profile with a useful
 * error. No token hash, credentials, recovery email, or backend request is sent.
 */
@RunWith(AndroidJUnit4::class)
class RecoveryDeepLinkSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun incompleteRecoveryLinkShowsErrorOnProfile() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val device = UiDevice.getInstance(instrumentation)
        val context = instrumentation.targetContext
        device.waitForIdle(5_000)
        assertNotNull("EduT should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        try {
            val link = Intent(Intent.ACTION_VIEW,
                Uri.parse("grantly://login-callback#type=recovery")).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                addCategory(Intent.CATEGORY_DEFAULT)
                setPackage(context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            context.startActivity(link)
            assertNotNull("Incomplete recovery link should show its error",
                device.wait(Until.findObject(By.textContains("recovery link is incomplete")), 20_000))
            assertNotNull("Recovery error should open the Profile sign-in screen",
                device.wait(Until.findObject(By.text("Welcome back")), 10_000))
        } finally {
            // Clear the guest-only recovery error so subsequent tests start clean.
            runBlocking { AuthRepository.signOut() }
        }
    }
}
