import Foundation
import Supabase

enum DataService {
    static func trackProductEvent(
        _ eventName: String,
        scholarshipId: UUID? = nil,
        properties: [String: String] = [:]
    ) async throws {
        let userId = try? await supabase.auth.session.user.id

        struct Row: Encodable {
            let user_id: UUID?
            let event_name: String
            let scholarship_id: UUID?
            let properties: [String: String]
        }

        try await supabase
            .from("product_events")
            .insert(
                Row(
                    user_id: userId,
                    event_name: eventName,
                    scholarship_id: scholarshipId,
                    properties: properties
                )
            )
            .execute()
    }

    static func adminAnalyticsSummary(
        days: Int = 30
    ) async throws -> AdminAnalyticsSummary {
        struct Params: Encodable {
            let p_days: Int
        }

        return try await supabase
            .rpc(
                "admin_analytics_summary",
                params: Params(p_days: days)
            )
            .execute()
            .value
    }

    static func scholarshipDuplicateCandidates(
        title: String,
        provider: String,
        country: String
    ) async throws -> [ScholarshipDuplicateCandidate] {
        struct Params: Encodable {
            let p_title: String
            let p_provider: String
            let p_country: String
        }

        return try await supabase
            .rpc(
                "find_scholarship_duplicates",
                params: Params(
                    p_title: title,
                    p_provider: provider,
                    p_country: country
                )
            )
            .execute()
            .value
    }

    static func adminSystemHealth() async throws -> AdminSystemHealth {
        try await supabase
            .rpc("admin_system_health")
            .execute()
            .value
    }

    static func recentAdminActionLogs(
        limit: Int = 20
    ) async throws -> [AdminActionLog] {
        try await supabase
            .from("admin_action_logs")
            .select("id,action,target_type,target_ids,created_at")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func adminBulkUpdateScholarships(
        ids: [UUID],
        action: String
    ) async throws -> Int {
        struct Params: Encodable {
            let p_ids: [UUID]
            let p_action: String
        }

        return try await supabase
            .rpc(
                "admin_bulk_update_scholarships",
                params: Params(
                    p_ids: ids,
                    p_action: action
                )
            )
            .execute()
            .value
    }

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
        let rows: [Scholarship] = try await supabase
            .from("scholarships")
            .select("*, university:universities(*)")
            .eq("status", value: "published")
            .order("title", ascending: true)
            .execute()
            .value

        return rows.filter {
            $0.verificationStatus != "needs_review" &&
            $0.linkStatus != "dead" &&
            $0.linkStatus != "generic"
        }
    }

    static func scholarshipFilterOptions() async throws -> ScholarshipFilterOptions {
        try await supabase
            .rpc("scholarship_filter_options")
            .execute()
            .value
    }

    static func allScholarshipsForAdmin() async throws -> [Scholarship] {
        try await supabase
            .from("scholarships")
            .select()
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func enrichUniversityMedia(
        limit: Int = 10
    ) async throws -> UniversityMediaEnrichmentResult {
        struct Body: Encodable {
            let limit: Int
        }

        return try await supabase.functions.invoke(
            "enrich-university-media",
            options: FunctionInvokeOptions(
                body: Body(limit: limit)
            )
        )
    }

    static func auditScholarships(limit: Int = 20) async throws -> ScholarshipAuditResult {
        struct Body: Encodable {
            let limit: Int
        }

        return try await supabase.functions.invoke(
            "audit-scholarships",
            options: FunctionInvokeOptions(
                body: Body(limit: limit)
            )
        )
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

        try? await trackProductEvent(
            saved ? "scholarship_save" : "scholarship_unsave",
            scholarshipId: scholarshipId
        )
    }

    static func setRecommendationFeedback(
        scholarshipId: UUID,
        feedback: String?
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        if let feedback {
            struct Row: Encodable {
                let user_id: UUID
                let scholarship_id: UUID
                let feedback: String
                let updated_at: String
            }

            try await supabase
                .from("recommendation_feedback")
                .upsert(
                    Row(
                        user_id: userId,
                        scholarship_id: scholarshipId,
                        feedback: feedback,
                        updated_at: ISO8601DateFormatter()
                            .string(from: Date())
                    ),
                    onConflict: "user_id,scholarship_id"
                )
                .execute()
        } else {
            try await supabase
                .from("recommendation_feedback")
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
                application_deadline,
                personal_deadline,
                submitted_at,
                interview_at,
                result_at,
                documents_complete,
                reminder_enabled,
                scholarships!saved_scholarships_scholarship_id_fkey (*, university:universities(*))
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
        struct Params: Encodable {
            let p_scholarship_id: UUID
            let p_status: String
        }

        try await supabase
            .rpc(
                "set_application_status",
                params: Params(
                    p_scholarship_id: scholarshipId,
                    p_status: status
                )
            )
            .execute()

        try? await trackProductEvent(
            "application_status_change",
            scholarshipId: scholarshipId,
            properties: ["status": status]
        )
    }

    static func applicationTasks(
        scholarshipId: UUID
    ) async throws -> [ApplicationTask] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("application_tasks")
            .select("id,scholarship_id,task_key,title,due_at,completed_at,position")
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .order("position", ascending: true)
            .execute()
            .value
    }

    static func setApplicationTaskCompleted(
        taskId: UUID,
        completed: Bool
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let completed_at: String?
            let updated_at: String
        }

        try await supabase
            .from("application_tasks")
            .update(
                Row(
                    completed_at: completed
                        ? ISO8601DateFormatter().string(from: Date())
                        : nil,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
            )
            .eq("id", value: taskId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func updateApplicationTracker(
        scholarshipId: UUID,
        personalDeadline: String?,
        documentsComplete: Bool,
        reminderEnabled: Bool
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let personal_deadline: String?
            let documents_complete: Bool
            let reminder_enabled: Bool
            let updated_at: String
        }

        try await supabase
            .from("saved_scholarships")
            .update(
                Row(
                    personal_deadline: personalDeadline,
                    documents_complete: documentsComplete,
                    reminder_enabled: reminderEnabled,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
            )
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

    static func appNotifications(
        limit: Int = 100
    ) async throws -> [AppNotification] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("app_notifications")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func markNotificationRead(
        notificationId: UUID
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let read_at: String
        }

        try await supabase
            .from("app_notifications")
            .update(
                Row(
                    read_at: ISO8601DateFormatter()
                        .string(from: Date())
                )
            )
            .eq("id", value: notificationId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func markAllNotificationsRead() async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let read_at: String
        }

        try await supabase
            .from("app_notifications")
            .update(
                Row(
                    read_at: ISO8601DateFormatter()
                        .string(from: Date())
                )
            )
            .eq("user_id", value: userId.uuidString)
            .is("read_at", value: nil)
            .execute()
    }

    static func registerPushDevice(
        token: String,
        environment: String
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let user_id: UUID
            let platform: String
            let token: String
            let environment: String
            let updated_at: String
        }

        try await supabase
            .from("push_devices")
            .upsert(
                Row(
                    user_id: userId,
                    platform: "ios",
                    token: token,
                    environment: environment,
                    updated_at: ISO8601DateFormatter()
                        .string(from: Date())
                ),
                onConflict: "token"
            )
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

    static func conversationSummaries() async throws -> [ConversationSummaryRow] {
        try await supabase
            .rpc("get_my_conversation_summaries")
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

    static func messagesPage(
        conversationId: UUID,
        before: String? = nil,
        limit: Int = 40
    ) async throws -> [Message] {
        struct Params: Encodable {
            let p_conversation_id: UUID
            let p_before: String?
            let p_limit: Int
        }

        let rows: [Message] = try await supabase
            .rpc(
                "get_messages_page",
                params: Params(
                    p_conversation_id: conversationId,
                    p_before: before,
                    p_limit: limit
                )
            )
            .execute()
            .value

        return rows.reversed()
    }

    static func markConversationRead(
        conversationId: UUID
    ) async throws {
        struct Params: Encodable {
            let p_conversation_id: UUID
        }

        try await supabase
            .rpc(
                "mark_conversation_read",
                params: Params(
                    p_conversation_id: conversationId
                )
            )
            .execute()
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
