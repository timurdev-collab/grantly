package com.grantly.android

/** Public scholarship data model, mapped from the existing iOS Scholarship model. */
internal data class Scholarship(
    val id: String,
    val title: String,
    val provider: String,
    val country: String,
    val fundingType: String,
    val degreeLevels: List<String>,
    val fields: List<String>,
    val deadline: String?,
    val description: String?,
    val officialUrl: String?,
    val verificationStatus: String?
)

/** Catalog integration is intentionally disabled until secure Android configuration is verified. */
internal object ScholarshipRepository {
    suspend fun fetchPublished(): List<Scholarship> {
        return emptyList()
    }
}
