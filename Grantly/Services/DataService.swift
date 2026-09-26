import Foundation
import Supabase

enum DataService {
    static func currentProfile(userId: UUID) async throws -> StudentProfile {
        try await supabase
            .from("student_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    static func currentCommunityProfile(userId: UUID) async throws -> CommunityProfile {
        try await supabase
            .from("community_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    static func scholarships() async throws -> [Scholarship] {
        try await supabase
            .from("scholarships")
            .select()
            .eq("status", value: "published")
            .order("title", ascending: true)
            .execute()
            .value
    }

    static func savedScholarshipIDs(userId: UUID) async throws -> Set<UUID> {
        let rows: [SavedScholarship] = try await supabase
            .from("saved_scholarships")
            .select("scholarship_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return Set(rows.map(\.scholarshipId))
    }

    static func setSaved(_ saved: Bool, userId: UUID, scholarshipId: UUID) async throws {
        if saved {
            struct SaveRow: Encodable {
                let user_id: UUID
                let scholarship_id: UUID
            }

            try await supabase
                .from("saved_scholarships")
                .insert(SaveRow(user_id: userId, scholarship_id: scholarshipId))
                .execute()
        } else {
            try await supabase
                .from("saved_scholarships")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("scholarship_id", value: scholarshipId.uuidString)
                .execute()
        }
    }

    static func savedScholarshipItems() async throws -> [SavedScholarshipItem] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("saved_scholarships")
            .select("""
                scholarship_id,
                application_status,
                notes,
                scholarships!saved_scholarships_scholarship_id_fkey (*)
            """)
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func updateApplicationStatus(
        scholarshipId: UUID,
        status: String
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("saved_scholarships")
            .update([
                "application_status": status,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .execute()
    }

    static func updateScholarshipNotes(
        scholarshipId: UUID,
        notes: String
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("saved_scholarships")
            .update([
                "notes": notes,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .execute()
    }

    static func communityProfiles() async throws -> [CommunityProfile] {
        try await supabase
            .from("community_profiles")
            .select()
            .eq("is_visible", value: true)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func conversationMemberships(userId: UUID) async throws -> [ConversationMember] {
        try await supabase
            .from("conversation_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
    }

    static func conversationMembers(conversationId: UUID) async throws -> [ConversationMember] {
        try await supabase
            .from("conversation_members")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .execute()
            .value
    }

    static func messages(conversationId: UUID) async throws -> [Message] {
        try await supabase
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func sendMessage(conversationId: UUID, senderId: UUID, body: String) async throws {
        struct Row: Encodable {
            let conversation_id: UUID
            let sender_id: UUID
            let body: String
        }

        try await supabase
            .from("messages")
            .insert(Row(conversation_id: conversationId, sender_id: senderId, body: body))
            .execute()
    }

    static func startDirectConversation(otherUser: UUID) async throws -> UUID {
        struct Params: Encodable {
            let other_user: UUID
        }

        let id: UUID = try await supabase
            .rpc("start_direct_conversation", params: Params(other_user: otherUser))
            .execute()
            .value
        return id
    }

    static func updateProfile(
        userId: UUID,
        fullName: String,
        nationality: String,
        residenceCountry: String,
        graduationYear: Int?,
        gpaValue: Double?,
        gpaScale: Double?,
        ielts: Double?,
        intendedMajor: String,
        degreeLevel: String,
        targetRegions: [String],
        targetCountries: [String],
        familyIncomeUSD: Double?
    ) async throws {
        struct Row: Encodable {
            let full_name: String
            let nationality: String
            let residence_country: String
            let graduation_year: Int?
            let gpa_value: Double?
            let gpa_scale: Double?
            let ielts: Double?
            let intended_major: String
            let degree_level: String
            let target_regions: [String]
            let target_countries: [String]
            let family_income_usd: Double?
        }

        let row = Row(
            full_name: fullName,
            nationality: nationality,
            residence_country: residenceCountry,
            graduation_year: graduationYear,
            gpa_value: gpaValue,
            gpa_scale: gpaScale,
            ielts: ielts,
            intended_major: intendedMajor,
            degree_level: degreeLevel,
            target_regions: targetRegions,
            target_countries: targetCountries,
            family_income_usd: familyIncomeUSD
        )

        try await supabase
            .from("student_profiles")
            .update(row)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    static func submitSafetyReport(
        reportedUserId: UUID,
        messageId: UUID? = nil,
        reason: String,
        details: String
    ) async throws {
        let reporterId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let reporter_id: UUID
            let reported_user_id: UUID
            let message_id: UUID?
            let reason: String
            let details: String
        }

        let row = Row(
            reporter_id: reporterId,
            reported_user_id: reportedUserId,
            message_id: messageId,
            reason: reason,
            details: details
        )

        try await supabase
            .from("safety_reports")
            .insert(row)
            .execute()
    }

    static func blockedUserIDs() async throws -> Set<UUID> {
        let userId = try await supabase.auth.session.user.id

        struct BlockRow: Decodable {
            let blockedId: UUID

            enum CodingKeys: String, CodingKey {
                case blockedId = "blocked_id"
            }
        }

        let rows: [BlockRow] = try await supabase
            .from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: userId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.blockedId))
    }

    static func blockUser(_ blockedUserId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }

        try await supabase
            .from("user_blocks")
            .insert(Row(blocker_id: userId, blocked_id: blockedUserId))
            .execute()
    }

    static func unblockUser(_ blockedUserId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("user_blocks")
            .delete()
            .eq("blocker_id", value: userId.uuidString)
            .eq("blocked_id", value: blockedUserId.uuidString)
            .execute()
    }

    static func safetyReports() async throws -> [SafetyReport] {
        try await supabase
            .from("safety_reports")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func updateSafetyReportStatus(
        reportId: UUID,
        status: String
    ) async throws {
        struct Row: Encodable {
            let status: String
            let resolved_at: String?
        }

        let resolvedAt = ["resolved", "dismissed"].contains(status)
            ? ISO8601DateFormatter().string(from: Date())
            : nil

        try await supabase
            .from("safety_reports")
            .update(Row(status: status, resolved_at: resolvedAt))
            .eq("id", value: reportId.uuidString)
            .execute()
    }

    static func updateCommunityProfile(
        userId: UUID,
        displayName: String,
        nationality: String,
        major: String,
        targetRegions: [String],
        targetCountries: [String],
        bio: String,
        isVisible: Bool
    ) async throws {
        struct Row: Encodable {
            let id: UUID
            let display_name: String
            let nationality: String
            let major: String
            let target_regions: [String]
            let target_countries: [String]
            let bio: String
            let is_visible: Bool
            let updated_at: String
        }

        let row = Row(
            id: userId,
            display_name: displayName,
            nationality: nationality,
            major: major,
            target_regions: targetRegions,
            target_countries: targetCountries,
            bio: bio,
            is_visible: isVisible,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("community_profiles")
            .upsert(row)
            .execute()
    }
}
