package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorIncomingConsultationRulesTest {
    private fun item(id: String, status: String) = AdvisorIncomingConsultation(
        id = id,
        studentName = "Student",
        serviceTitle = "Application review",
        topic = "",
        status = status,
        durationMinutes = 30,
        priceCents = 2500,
        currency = "USD",
        preferredStart = "",
        createdAt = ""
    )

    @Test fun openAndClosedFiltersPreserveServerOrder() {
        val items = listOf(
            item("1", "requested"), item("2", "paid"),
            item("3", "completed"), item("4", "cancelled"), item("5", "confirmed")
        )
        assertEquals(listOf("1", "2", "5"),
            AdvisorIncomingConsultationRules.visible(items, "open").map { it.id })
        assertEquals(listOf("3", "4"),
            AdvisorIncomingConsultationRules.visible(items, "closed").map { it.id })
        assertEquals(items, AdvisorIncomingConsultationRules.visible(items, "all"))
    }

    @Test fun focusedFiltersPreserveOrderAndNeverTreatUnknownAsPaid() {
        val items = listOf(
            item("1", "requested"), item("2", "awaiting_payment"),
            item("3", "paid"), item("4", "confirmed"),
            item("5", "completed"), item("6", "cancelled"),
            item("7", "unexpected"), item("8", "requested"),
            item("9", "contacted")
        )
        assertEquals(listOf("1", "8"),
            AdvisorIncomingConsultationRules.visible(items, "new").map { it.id })
        assertEquals(listOf("9"),
            AdvisorIncomingConsultationRules.visible(items, "contacted").map { it.id })
        assertEquals(listOf("2"),
            AdvisorIncomingConsultationRules.visible(items, "payment").map { it.id })
        assertEquals(listOf("3", "4"),
            AdvisorIncomingConsultationRules.visible(items, "ready").map { it.id })
        assertEquals(listOf("5", "6"),
            AdvisorIncomingConsultationRules.visible(items, "closed").map { it.id })
        assertEquals(listOf("7"),
            AdvisorIncomingConsultationRules.visible(items, "other").map { it.id })
        assertEquals(listOf("1", "2", "3", "4", "8", "9"),
            AdvisorIncomingConsultationRules.visible(items, "open").map { it.id })
        assertEquals(items, AdvisorIncomingConsultationRules.visible(items, "all"))
    }

    @Test fun contactIsNeverUnlockedForUnverifiedPayment() {
        listOf("requested", "contacted", "awaiting_payment", "cancelled", "unknown")
            .forEach { assertFalse(AdvisorIncomingConsultationRules.contactUnlocked(it)) }
        listOf("paid", "confirmed", "completed")
            .forEach { assertTrue(AdvisorIncomingConsultationRules.contactUnlocked(it)) }
    }

    @Test fun pageLimitsAreBoundedAndDoNotMutateInput() {
        val items = (1..50).map { item(it.toString(), "requested") }
        assertEquals(0, AdvisorIncomingConsultationRules.page(items, -1).size)
        assertEquals(20, AdvisorIncomingConsultationRules.page(items, 20).size)
        assertEquals(50, AdvisorIncomingConsultationRules.page(items, 100).size)
        assertEquals(50, items.size)
    }

    @Test fun unknownStatusesAreNotPresentedAsVerified() {
        assertEquals("Unknown status", AdvisorIncomingConsultationRules.statusLabel("pending_transfer"))
        assertEquals("Awaiting payment", AdvisorIncomingConsultationRules.statusLabel("awaiting_payment"))
        assertFalse(AdvisorIncomingConsultationRules.isOpen("pending_transfer"))
        assertFalse(AdvisorIncomingConsultationRules.isKnown("pending_transfer"))
        assertTrue(AdvisorIncomingConsultationRules.isKnown("contacted"))
        assertTrue(AdvisorIncomingConsultationRules.isOpen("contacted"))
        assertFalse(AdvisorIncomingConsultationRules.isOpen("cancelled"))
    }
}
