package com.grantly.android

import androidx.compose.runtime.Composable
import androidx.compose.runtime.key

/**
 * Compatibility entry point while the iOS study-level filters are being ported.
 * The existing Discover screen remains responsible for scholarship loading.
 * Initial-degree synchronization is tracked as follow-up work.
 */
@Composable
internal fun ScholarshipDiscoverContent(
    initialDegree: String,
    onSelect: (Scholarship) -> Unit
) {
    key(initialDegree) {
        ScholarshipDiscoverContent(onSelect = onSelect)
    }
}
