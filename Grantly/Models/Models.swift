import Foundation

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

struct Scholarship: Codable, Identifiable, Hashable {
    let id: UUID
    var slug: String
    var title: String
    var provider: String
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

    enum CodingKeys: String, CodingKey {
        case id, slug, title, provider, country, region, fields, stipend, airfare, accommodation, status, deadline
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
