package com.grantly.android

import android.content.Context
import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Verify the Home-only language choice changes visible labels and survives
 * Activity recreation. This does not imply that the entire app is localized.
 */
@RunWith(AndroidJUnit4::class)
class GuestHomeLanguagePersistenceSmokeTest {
    @get:Rule val composeRule = createAndroidComposeRule<MainActivity>()

    @Test fun selectingRussianUpdatesHomeAndSurvivesRecreation() {
        val preferences = composeRule.activity.getSharedPreferences(
            "edut_home_language", Context.MODE_PRIVATE
        )
        try {
            // Make the test independent of any previously saved device language.
            preferences.edit().putString("language", "en").commit()
            composeRule.activityRule.scenario.recreate()

            composeRule.onNodeWithContentDescription(
                "Home language preview: English"
            ).assertExists().performClick()
            composeRule.onNodeWithText("🇷🇺 Русский").assertExists().performClick()
            composeRule.onNodeWithText("Нужна помощь?").assertExists()
            assertEquals("ru", preferences.getString("language", null))

            composeRule.activityRule.scenario.recreate()
            composeRule.onNodeWithContentDescription(
                "Home language preview: Русский"
            ).assertExists()
            composeRule.onNodeWithText("Нужна помощь?").assertExists()
        } finally {
            // Do not leak the selected language into other emulator tests.
            preferences.edit().remove("language").commit()
        }
    }
}
