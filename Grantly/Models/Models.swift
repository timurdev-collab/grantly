import Foundation
import Supabase

struct StudentProfile: Codable, Identifiable {
    let id: UUID
    var fullName: String?
    var nationality: String?
    var residenceCountry: String?
    var graduationYear: Int?
    var gpaValue: Double?
    var gpaScale: Double?
    var ielts: Double?
    var intendedMajor: String?
    var degreeLevel: String?
    var targetRegions: [String]?
    var targetCountries: [String]?
    var familyIncomeUSD: Double?
    var role: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case nationality
        case residenceCountry = "residence_country"
        case graduationYear = "graduation_year"
        case gpaValue = "gpa_value"
        case gpaScale = "gpa_scale"
        case ielts
        case intendedMajor = "intended_major"
        case degreeLevel = "degree_level"
        case targetRegions = "target_regions"
        case targetCountries = "target_countries"
        case familyIncomeUSD = "family_income_usd"
        case role
    }
}

struct CommunityProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String?
    var nationality: String?
    var major: String?
    var targetRegions: [String]?
    var targetCountries: [String]?
    var bio: String?
    var isVisible: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case nationality, major
        case targetRegions = "target_regions"
        case targetCountries = "target_countries"
        case bio
        case isVisible = "is_visible"
    }
}

struct University: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var country: String
    var city: String?
    var websiteUrl: String?
    var logoUrl: String?
    var campusImageUrl: String?
    var description: String?
    var entityType: String
    var isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, country, city, description
        case websiteUrl = "website_url"
        case logoUrl = "logo_url"
        case campusImageUrl = "campus_image_url"
        case entityType = "entity_type"
        case isVerified = "is_verified"
    }
}

struct Scholarship: Codable, Identifiable, Hashable {
    let id: UUID
    var slug: String
    var title: String
    var provider: String
    var universityId: UUID?
    var university: University?
    var country: String
    var region: String
    var degreeLevels: [String]
    var fields: [String]
    var fundingType: String
    var tuitionCoverage: String?
    var stipend: String?
    var airfare: Bool
    var accommodation: Bool
    var healthInsurance: Bool
    var minGpaPercent: Double?
    var minIelts: Double?
    var satRequired: Bool
    var eligibleNationalities: [String]
    var deadline: String?
    var officialUrl: String
    var status: String
    var verifiedAt: String?
    var description: String?
    var sourceLabel: String?
    var sourceUrl: String?
    var sourceLicense: String?
    var verificationStatus: String?
    var applicationCycle: String?
    var deadlineNotes: String?
    var linkStatus: String?
    var lastCheckedAt: String?
    var finalUrl: String?
    var deadlineCandidate: String?
    var deadlineConfidence: Int?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, provider, university, country, region, fields, stipend, airfare, accommodation, status, deadline
        case universityId = "university_id"
        case degreeLevels = "degree_levels"
        case fundingType = "funding_type"
        case tuitionCoverage = "tuition_coverage"
        case healthInsurance = "health_insurance"
        case minGpaPercent = "min_gpa_percent"
        case minIelts = "min_ielts"
        case satRequired = "sat_required"
        case eligibleNationalities = "eligible_nationalities"
        case officialUrl = "official_url"
        case verifiedAt = "verified_at"
        case description
        case sourceLabel = "source_label"
        case sourceUrl = "source_url"
        case sourceLicense = "source_license"
        case verificationStatus = "verification_status"
        case applicationCycle = "application_cycle"
        case deadlineNotes = "deadline_notes"
        case linkStatus = "link_status"
        case lastCheckedAt = "last_checked_at"
        case finalUrl = "final_url"
        case deadlineCandidate = "deadline_candidate"
        case deadlineConfidence = "deadline_confidence"
    }
}

struct SavedScholarship: Codable {
    let scholarshipId: UUID
    enum CodingKeys: String, CodingKey { case scholarshipId = "scholarship_id" }
}

struct ConversationMember: Codable {
    let conversationId: UUID
    let userId: UUID
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
    }
}

struct Message: Codable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let body: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, body
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
    }
}

struct SafetyReport: Codable, Identifiable {
    let id: UUID
    let reporterId: UUID?
    let reportedUserId: UUID?
    let messageId: UUID?
    let reason: String
    let details: String
    let status: String
    let createdAt: String
    let resolvedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, reason, details, status
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case messageId = "message_id"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }
}

struct ScholarshipMatch: Identifiable {
    var id: UUID { scholarship.id }
    let scholarship: Scholarship
    let score: Int
    let eligible: Bool
    let reasons: [String]
    let blockers: [String]
}


struct ScholarshipAuditResult: Decodable {
    let audited: Int
    let exact: Int
    let generic: Int
    let dead: Int
    let reachable: Int
    let deadlineCandidates: Int
}


struct ScholarshipSearchRow: Decodable {
    let scholarship: Scholarship
    let totalCount: Int
    let isSaved: Bool

    enum CodingKeys: String, CodingKey {
        case scholarship
        case totalCount = "total_count"
        case isSaved = "is_saved"
    }
}

struct ScholarshipSearchPage {
    let scholarships: [Scholarship]
    let totalCount: Int
    let savedScholarshipIDs: Set<UUID>
}

struct ScholarshipMatchRow: Decodable {
    let scholarship: Scholarship
    let score: Int
    let eligible: Bool
    let reasons: [String]
    let blockers: [String]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case scholarship
        case score
        case eligible
        case reasons
        case blockers
        case totalCount = "total_count"
    }
}

struct ScholarshipMatchPage {
    let matches: [ScholarshipMatch]
    let totalCount: Int
}

struct ScholarshipFilterOptions: Decodable {
    let countries: [String]
    let degrees: [String]
    let fields: [String]
    let funding: [String]
}


enum ScholarshipSearchService {
    private struct SearchParams: Encodable {
        let p_query: String?
        let p_country: String?
        let p_degree: String?
        let p_field: String?
        let p_funding: String?
        let p_source: String?
        let p_sort: String
        let p_offset: Int
        let p_limit: Int
    }

    static func search(
        query: String?,
        country: String?,
        degree: String?,
        field: String?,
        funding: String?,
        source: String?,
        sort: String,
        offset: Int,
        limit: Int
    ) async throws -> ScholarshipSearchPage {
        let rows: [ScholarshipSearchRow] = try await supabase
            .rpc(
                "search_scholarships",
                params: SearchParams(
                    p_query: query,
                    p_country: country,
                    p_degree: degree,
                    p_field: field,
                    p_funding: funding,
                    p_source: source,
                    p_sort: sort,
                    p_offset: offset,
                    p_limit: limit
                )
            )
            .execute()
            .value

        return ScholarshipSearchPage(
            scholarships: rows.map { $0.scholarship },
            totalCount: rows.first?.totalCount ?? 0,
            savedScholarshipIDs: Set(
                rows.filter { $0.isSaved }.map { $0.scholarship.id }
            )
        )
    }

    static func filters() async throws -> ScholarshipFilterOptions {
        try await supabase
            .rpc("scholarship_filter_options")
            .execute()
            .value
    }

    private struct MatchParams: Encodable {
        let p_offset: Int
        let p_limit: Int
    }

    static func matches(
        offset: Int = 0,
        limit: Int = 24
    ) async throws -> ScholarshipMatchPage {
        let rows: [ScholarshipMatchRow] = try await supabase
            .rpc(
                "get_my_scholarship_matches",
                params: MatchParams(
                    p_offset: offset,
                    p_limit: limit
                )
            )
            .execute()
            .value

        return ScholarshipMatchPage(
            matches: rows.map {
                ScholarshipMatch(
                    scholarship: $0.scholarship,
                    score: $0.score,
                    eligible: $0.eligible,
                    reasons: $0.reasons,
                    blockers: $0.blockers
                )
            },
            totalCount: rows.first?.totalCount ?? 0
        )
    }
}


struct UniversityMediaEnrichmentResult: Decodable {
    let enriched: Int
    let ready: Int
    let partial: Int
    let failed: Int
}


struct ApplicationTask: Codable, Identifiable, Hashable {
    let id: UUID
    let scholarshipId: UUID
    let taskKey: String?
    let title: String
    let dueAt: String?
    let completedAt: String?
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id, title, position
        case scholarshipId = "scholarship_id"
        case taskKey = "task_key"
        case dueAt = "due_at"
        case completedAt = "completed_at"
    }
}

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let kind: String
    let title: String
    let body: String
    let scholarshipId: UUID?
    let taskId: UUID?
    let readAt: String?
    let scheduledFor: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body
        case scholarshipId = "scholarship_id"
        case taskId = "task_id"
        case readAt = "read_at"
        case scheduledFor = "scheduled_for"
        case createdAt = "created_at"
    }
}
