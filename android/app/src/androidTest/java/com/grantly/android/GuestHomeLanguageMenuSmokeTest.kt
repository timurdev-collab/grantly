package com.grantly.android

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The Home language preview menu must be discoverable without a sign-in.
 * This test does not change persisted language or imply full app localization.
 */
@RunWith(AndroidJUnit4::class)
class GuestHomeLanguageMenuSmokeTest {
    @get:Rule val composeRule = createAndroidComposeRule<MainActivity>()

    @Test fun homeLanguageMenuListsIosOptionsAndExplainsLimitedScope() {
        composeRule.onNodeWithContentDescription(
            "Home language preview:", substring = true
        ).assertExists().performClick()
        composeRule.onNodeWithText("🇬🇧 English").assertExists()
        composeRule.onNodeWithText("🇷🇺 Русский").assertExists()
        composeRule.onNodeWithText("🇨🇳 中文").assertExists()
        composeRule.onNodeWithText(
            "Home labels only · Other screens remain in English"
        ).assertExists()
    }
}
