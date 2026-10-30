package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorConsultationActionRulesTest {
    @Test fun onlyPaidCanBeConfirmed() {
        assertTrue(AdvisorConsultationActionRules.allowed("paid", "confirmed"))
        for (status in listOf("requested", "contacted", "awaiting_payment", "confirmed",
            "completed", "cancelled", "unknown", "")) {
            assertFalse(AdvisorConsultationActionRules.allowed(status, "confirmed"))
        }
    }

    @Test fun onlyConfirmedCanBeCompleted() {
        assertTrue(AdvisorConsultationActionRules.allowed("confirmed", "completed"))
        for (status in listOf("requested", "contacted", "awaiting_payment", "paid",
            "completed", "cancelled", "unknown", "")) {
            assertFalse(AdvisorConsultationActionRules.allowed(status, "completed"))
        }
    }

    @Test fun advisorCannotVerifyPaymentOrCancelViaThisControl() {
        for (status in listOf("requested", "contacted", "awaiting_payment", "paid",
            "confirmed", "completed", "cancelled", "unknown", "")) {
            assertFalse(AdvisorConsultationActionRules.allowed(status, "paid"))
            assertFalse(AdvisorConsultationActionRules.allowed(status, "cancelled"))
        }
        assertFalse(AdvisorConsultationActionRules.allowed("paid", "delete"))
    }

    @Test fun nextStatusAndLabelsMatchExistingRpc() {
        assertEquals("confirmed", AdvisorConsultationActionRules.nextStatus("paid"))
        assertEquals("completed", AdvisorConsultationActionRules.nextStatus("confirmed"))
        assertEquals(null, AdvisorConsultationActionRules.nextStatus("awaiting_payment"))
        assertEquals(null, AdvisorConsultationActionRules.nextStatus("completed"))
        assertEquals("Confirm consultation", AdvisorConsultationActionRules.label("confirmed"))
        assertEquals("Mark consultation completed", AdvisorConsultationActionRules.label("completed"))
    }
}
