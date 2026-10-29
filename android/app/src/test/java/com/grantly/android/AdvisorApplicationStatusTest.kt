package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AdvisorApplicationStatusTest {
    @Test fun mapsServerStatusesToReadableLabels() {
        assertEquals("Approved", advisorStatusTitle("approved"))
        assertEquals("Rejected", advisorStatusTitle("rejected"))
        assertEquals("Suspended", advisorStatusTitle("suspended"))
        assertEquals("Changes requested", advisorStatusTitle("changes_requested"))
        assertEquals("Pending review", advisorStatusTitle("pending"))
        // Unknown and missing states must never be presented as an approved workflow.
        assertEquals("Status unavailable", advisorStatusTitle("unexpected"))
        assertEquals("Status unavailable", advisorStatusTitle(""))
        assertEquals("Status unavailable", advisorStatusTitle("PENDING"))
    }
}
