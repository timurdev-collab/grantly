package com.grantly.android

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Non-mutating guest smoke coverage for both Home refresh entry points.
 * Checks UI stability, not successful network reloads or account-specific data.
 */
@RunWith(AndroidJUnit4::class)
class GuestHomeRefreshSmokeTest {
    @get:Rule val composeRule = createAndroidComposeRule<MainActivity>()

    @Test fun refreshButtonAndPullGestureKeepHomeUsable() {
        composeRule.onNodeWithContentDescription("Refresh Home")
            .assertExists().performClick()
        composeRule.onNodeWithText("For you").assertExists()

        // Start at the top of the Home root. A Compose gesture avoids
        // emulator coordinate drift caused by the system status bar.
        composeRule.onRoot().performTouchInput {
            swipeDown(durationMillis = 500L)
        }
        composeRule.waitForIdle()
        composeRule.onNodeWithContentDescription("Refresh Home").assertExists()
        composeRule.onNodeWithText("For you").assertExists()
    }
}
