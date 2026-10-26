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
 * Exercises only guest authentication navigation on a clean emulator.
 * Never submits credentials, sends recovery emails, or changes backend data.
 */
@RunWith(AndroidJUnit4::class)
class GuestAuthFlowSmokeTest {
    @get:Rule val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test fun guestCanNavigateSignupAndPasswordRecovery() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        device.waitForIdle(5_000)
        assertNotNull("EduT should launch",
            device.wait(Until.findObject(By.text("EduT")), 45_000))

        val profile = device.wait(Until.findObject(By.text("Profile")), 10_000)
        assertNotNull("Profile tab should be visible", profile)
        profile.click()
        assertNotNull("Sign-in screen should open",
            device.wait(Until.findObject(By.text("Welcome back")), 20_000))

        val showPassword = device.wait(Until.findObject(By.desc("Show password")), 10_000)
        assertNotNull("Sign-in should allow password visibility to be toggled", showPassword)
        showPassword.click()
        assertNotNull("Sign-in should allow hiding the password again",
            device.wait(Until.findObject(By.desc("Hide password")), 10_000))

        val signup = device.wait(
            Until.findObject(By.text("New to EduT? Create an account")), 10_000)
        assertNotNull("Signup action should be available", signup)
        signup.click()
        assertNotNull("Signup screen should open",
            device.wait(Until.findObject(By.text("Create your account")), 10_000))
        assertNotNull("Signup should start with its password concealed",
            device.wait(Until.findObject(By.desc("Show password")), 10_000))

        val backToLogin = device.wait(
            Until.findObject(By.text("Already have an account? Sign in")), 10_000)
        assertNotNull("Signup should offer sign-in", backToLogin)
        backToLogin.click()
        assertNotNull("Sign-in screen should return",
            device.wait(Until.findObject(By.text("Welcome back")), 10_000))

        val forgot = device.wait(Until.findObject(By.text("Forgot password?")), 10_000)
        assertNotNull("Password recovery should be reachable", forgot)
        forgot.click()
        assertNotNull("Recovery screen should open",
            device.wait(Until.findObject(By.text("Reset password")), 10_000))
        assertNotNull("Recovery should allow returning to sign-in",
            device.wait(Until.findObject(By.text("Back to sign in")), 10_000))
    }
}
