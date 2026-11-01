package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeLanguageTest {
    @Test fun languageCodesMatchIosAndAreUnique() {
        assertEquals(listOf("en", "ru", "vi", "ar", "zh-Hans", "fr", "es", "de"),
            HomeLanguage.entries.map { it.code })
        assertEquals(8, HomeLanguage.entries.map { it.code }.toSet().size)
    }

    @Test fun arabicIsTheOnlyRightToLeftLanguage() {
        HomeLanguage.entries.forEach { language ->
            assertEquals(language == HomeLanguage.ARABIC, language.isRightToLeft)
        }
    }

    @Test fun unknownOrMissingPreferenceFallsBackToEnglish() {
        assertEquals(HomeLanguage.ENGLISH, HomeLanguage.fromCode(null))
        assertEquals(HomeLanguage.ENGLISH, HomeLanguage.fromCode("invalid"))
        assertEquals(HomeLanguage.CHINESE, HomeLanguage.fromCode("zh-Hans"))
    }

    @Test fun allHomeLanguageOptionsHaveUsableLabels() {
        HomeLanguage.entries.forEach { language ->
            val labels = language.labels
            assertTrue(language.title.isNotBlank())
            assertTrue(language.flag.isNotBlank())
            assertTrue(labels.hero.isNotBlank())
            assertTrue(labels.search.isNotBlank())
            assertTrue(labels.forYou.isNotBlank())
            assertTrue(labels.pickedForYou.isNotBlank())
            assertTrue(labels.closingSoon.isNotBlank())
        }
    }

    @Test fun allNavigationDestinationsHaveLabelsForEachLanguage() {
        HomeLanguage.entries.forEach { language ->
            val nav = language.navigationLabels
            assertTrue(nav.home.isNotBlank())
            assertTrue(nav.explore.isNotBlank())
            assertTrue(nav.messages.isNotBlank())
            assertTrue(nav.advisor.isNotBlank())
            assertTrue(language.labels.applications.isNotBlank())
            assertTrue(language.labels.profile.isNotBlank())
        }
        assertEquals("Home", HomeLanguage.ENGLISH.navigationLabels.home)
        assertEquals("Explore", HomeLanguage.ENGLISH.navigationLabels.explore)
        assertEquals("Messages", HomeLanguage.ENGLISH.navigationLabels.messages)
        assertEquals("Advisor", HomeLanguage.ENGLISH.navigationLabels.advisor)
        assertEquals("Главная", HomeLanguage.RUSSIAN.navigationLabels.home)
        assertEquals("首页", HomeLanguage.CHINESE.navigationLabels.home)
    }

    @Test fun allHomeGuidanceAndCommunityLabelsAreTranslated() {
        HomeLanguage.entries.forEach { language ->
            val labels = language.secondaryLabels
            assertTrue(labels.guidanceTitle.isNotBlank())
            assertTrue(labels.guidanceDescription.isNotBlank())
            assertTrue(labels.guidanceAction.isNotBlank())
            assertTrue(labels.communityTitle.isNotBlank())
            assertTrue(labels.communityDescription.isNotBlank())
            assertTrue(labels.communityAction.isNotBlank())
            if (language != HomeLanguage.ENGLISH) {
                assertTrue(labels.guidanceTitle != HomeLanguage.ENGLISH.secondaryLabels.guidanceTitle)
                assertTrue(labels.communityDescription != HomeLanguage.ENGLISH.secondaryLabels.communityDescription)
            }
        }
    }
}
