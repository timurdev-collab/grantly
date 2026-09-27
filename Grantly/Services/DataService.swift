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

    static func scholarshipImportBatches(
        limit: Int = 20
    ) async throws -> [ScholarshipImportBatch] {
        try await supabase
            .from("scholarship_import_batches")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func scholarshipImportRows(
        batchId: UUID
    ) async throws -> [ScholarshipImportRow] {
        try await supabase
            .from("scholarship_import_rows")
            .select(
                "id,row_number,proposed_action,validation_errors," +
                "matched_scholarship_id,applied_scholarship_id"
            )
            .eq("batch_id", value: batchId.uuidString)
            .order("row_number", ascending: true)
            .execute()
            .value
    }

    static func stageScholarshipImport(
        format: String,
        content: String,
        sourceLabel: String,
        sourceURL: String?
    ) async throws -> ScholarshipImportStageResult {
        struct Body: Encodable {
            let format: String
            let content: String
            let source_label: String
            let source_url: String?
        }

        return try await supabase.functions.invoke(
            "import-scholarships",
            options: FunctionInvokeOptions(
                body: Body(
                    format: format,
                    content: content,
                    source_label: sourceLabel,
                    source_url: sourceURL
                )
            )
        )
    }

    static func commitScholarshipImport(
        batchId: UUID
    ) async throws -> ScholarshipImportCommitResult {
        struct Params: Encodable {
            let p_batch_id: UUID
        }

        return try await supabase
            .rpc(
                "commit_scholarship_import",
                params: Params(p_batch_id: batchId)
            )
            .execute()
            .value
    }

    static func rollbackScholarshipImport(
        batchId: UUID
    ) async throws -> ScholarshipImportRollbackResult {
        struct Params: Encodable {
            let p_batch_id: UUID
        }

        return try await supabase
            .rpc(
                "rollback_scholarship_import",
                params: Params(p_batch_id: batchId)
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

        let today = String(
            ISO8601DateFormatter()
                .string(from: Date())
                .prefix(10)
        )

        return rows.filter {
            let cycleVisible = !["closed", "discontinued"]
                .contains($0.cycleStatus ?? "unknown")
            let deadlineVisible = $0.deadline.map { $0 >= today } ?? true
            let deadlineStateVisible =
                $0.deadlineVerificationStatus != "expired"

            return $0.verificationStatus != "needs_review" &&
                $0.linkStatus != "dead" &&
                $0.linkStatus != "generic" &&
                cycleVisible &&
                deadlineVisible &&
                deadlineStateVisible
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
                application_reference,
                portal_last_checked_at,
                scholarships!saved_scholarships_scholarship_id_fkey (*, university:universities(*))
            """)
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func savedApplication(
        scholarshipId: UUID
    ) async throws -> SavedScholarshipItem? {
        let userId = try await supabase.auth.session.user.id

        let rows: [SavedScholarshipItem] = try await supabase
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
                application_reference,
                portal_last_checked_at,
                scholarships!saved_scholarships_scholarship_id_fkey (*, university:universities(*))
            """)
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    static func updateApplicationWorkspace(
        scholarshipId: UUID,
        reference: String,
        notes: String,
        personalDeadline: String?,
        documentsComplete: Bool,
        reminderEnabled: Bool
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let application_reference: String?
            let notes: String
            let personal_deadline: String?
            let documents_complete: Bool
            let reminder_enabled: Bool
            let updated_at: String
        }

        let cleanedReference = reference
            .trimmingCharacters(in: .whitespacesAndNewlines)

        try await supabase
            .from("saved_scholarships")
            .update(
                Row(
                    application_reference:
                        cleanedReference.isEmpty ? nil : cleanedReference,
                    notes: notes.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    personal_deadline: personalDeadline,
                    documents_complete: documentsComplete,
                    reminder_enabled: reminderEnabled,
                    updated_at: ISO8601DateFormatter()
                        .string(from: Date())
                )
            )
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .execute()
    }

    static func markApplicationPortalChecked(
        scholarshipId: UUID
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let portal_last_checked_at: String
            let updated_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await supabase
            .from("saved_scholarships")
            .update(
                Row(
                    portal_last_checked_at: now,
                    updated_at: now
                )
            )
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .execute()
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

    static func universityChoices() async throws -> [University] {
        try await supabase
            .from("universities")
            .select()
            .eq("entity_type", value: "university")
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func universityApplicationCases() async throws
        -> [UniversityApplicationCase] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("university_application_cases")
            .select("*, university:universities(*)")
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func createUniversityApplicationCase(
        universityId: UUID,
        programName: String,
        degreeLevel: String?,
        intake: String?
    ) async throws -> UUID {
        struct Params: Encodable {
            let p_university_id: UUID
            let p_program_name: String
            let p_degree_level: String?
            let p_intake: String?
        }

        return try await supabase
            .rpc(
                "create_university_application_case",
                params: Params(
                    p_university_id: universityId,
                    p_program_name: programName,
                    p_degree_level: degreeLevel,
                    p_intake: intake
                )
            )
            .execute()
            .value
    }

    static func universityCase(
        id: UUID
    ) async throws -> UniversityApplicationCase {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("university_application_cases")
            .select("*, university:universities(*)")
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    static func updateUniversityCase(
        id: UUID,
        programName: String,
        degreeLevel: String?,
        intake: String?,
        applicationReference: String?,
        deadline: String?,
        notes: String
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct Row: Encodable {
            let program_name: String
            let degree_level: String?
            let intake: String?
            let application_reference: String?
            let deadline: String?
            let notes: String
            let updated_at: String
        }

        try await supabase
            .from("university_application_cases")
            .update(
                Row(
                    program_name: programName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    degree_level: degreeLevel,
                    intake: intake,
                    application_reference: applicationReference?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    deadline: deadline,
                    notes: notes.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    updated_at: ISO8601DateFormatter()
                        .string(from: Date())
                )
            )
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func setUniversityCaseStatus(
        caseId: UUID,
        status: String
    ) async throws {
        struct Params: Encodable {
            let p_case_id: UUID
            let p_status: String
        }

        try await supabase
            .rpc(
                "set_university_case_status",
                params: Params(
                    p_case_id: caseId,
                    p_status: status
                )
            )
            .execute()
    }

    static func deleteUniversityCase(
        caseId: UUID
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        let documents = try await universityCaseDocuments(
            caseId: caseId
        )

        if !documents.isEmpty {
            try? await supabase.storage
                .from("university-case-documents")
                .remove(paths: documents.map(\.storagePath))
        }

        try await supabase
            .from("university_application_cases")
            .delete()
            .eq("id", value: caseId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func universityCaseRequirements(
        caseId: UUID
    ) async throws -> [UniversityCaseRequirement] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("university_case_requirements")
            .select()
            .eq("case_id", value: caseId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .order("position", ascending: true)
            .execute()
            .value
    }

    static func addUniversityCaseRequirement(
        caseId: UUID,
        title: String,
        category: String,
        required: Bool,
        sourceURL: String? = nil
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let existing = try await universityCaseRequirements(
            caseId: caseId
        )
        let nextPosition = (existing.map(\.position).max() ?? 0) + 10

        struct Row: Encodable {
            let case_id: UUID
            let user_id: UUID
            let title: String
            let category: String
            let is_required: Bool
            let is_official: Bool
            let source_url: String?
            let position: Int
        }

        try await supabase
            .from("university_case_requirements")
            .insert(
                Row(
                    case_id: caseId,
                    user_id: userId,
                    title: title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    category: category,
                    is_required: required,
                    is_official: sourceURL != nil,
                    source_url: sourceURL,
                    position: nextPosition
                )
            )
            .execute()
    }

    static func deleteUniversityCaseRequirement(
        requirementId: UUID
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("university_case_requirements")
            .delete()
            .eq("id", value: requirementId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func universityCaseDocuments(
        caseId: UUID
    ) async throws -> [UniversityCaseDocument] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("university_case_documents")
            .select()
            .eq("case_id", value: caseId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func uploadUniversityCaseDocument(
        caseId: UUID,
        requirementId: UUID?,
        fileName: String,
        data: Data,
        contentType: String
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let safeName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let path =
            "\(userId.uuidString.lowercased())/" +
            "\(caseId.uuidString.lowercased())/" +
            "\(UUID().uuidString.lowercased())-\(safeName)"

        try await supabase.storage
            .from("university-case-documents")
            .upload(
                path: path,
                file: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: contentType,
                    upsert: false
                )
            )

        struct Row: Encodable {
            let case_id: UUID
            let requirement_id: UUID?
            let user_id: UUID
            let file_name: String
            let storage_path: String
            let content_type: String
            let byte_size: Int
        }

        do {
            try await supabase
                .from("university_case_documents")
                .insert(
                    Row(
                        case_id: caseId,
                        requirement_id: requirementId,
                        user_id: userId,
                        file_name: fileName,
                        storage_path: path,
                        content_type: contentType,
                        byte_size: data.count
                    )
                )
                .execute()
        } catch {
            try? await supabase.storage
                .from("university-case-documents")
                .remove(paths: [path])
            throw error
        }
    }

    static func deleteUniversityCaseDocument(
        _ document: UniversityCaseDocument
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase.storage
            .from("university-case-documents")
            .remove(paths: [document.storagePath])

        try await supabase
            .from("university_case_documents")
            .delete()
            .eq("id", value: document.id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    static func applicationDocuments(
        scholarshipId: UUID
    ) async throws -> [ApplicationDocument] {
        let userId = try await supabase.auth.session.user.id

        return try await supabase
            .from("application_documents")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("scholarship_id", value: scholarshipId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func uploadApplicationDocument(
        scholarshipId: UUID,
        fileName: String,
        data: Data,
        contentType: String
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let safeName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let path =
            "\(userId.uuidString.lowercased())/" +
            "\(scholarshipId.uuidString.lowercased())/" +
            "\(UUID().uuidString.lowercased())-\(safeName)"

        try await supabase.storage
            .from("application-documents")
            .upload(
                path: path,
                file: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: contentType,
                    upsert: false
                )
            )

        struct Row: Encodable {
            let user_id: UUID
            let scholarship_id: UUID
            let file_name: String
            let storage_path: String
            let content_type: String
            let byte_size: Int
        }

        do {
            try await supabase
                .from("application_documents")
                .insert(
                    Row(
                        user_id: userId,
                        scholarship_id: scholarshipId,
                        file_name: fileName,
                        storage_path: path,
                        content_type: contentType,
                        byte_size: data.count
                    )
                )
                .execute()
        } catch {
            try? await supabase.storage
                .from("application-documents")
                .remove(paths: [path])
            throw error
        }

        try? await trackProductEvent(
            "application_document_upload",
            scholarshipId: scholarshipId,
            properties: ["content_type": contentType]
        )
    }

    static func deleteApplicationDocument(
        _ document: ApplicationDocument
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase.storage
            .from("application-documents")
            .remove(paths: [document.storagePath])

        try await supabase
            .from("application_documents")
            .delete()
            .eq("id", value: document.id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
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

    static func addApplicationTask(
        scholarshipId: UUID,
        title: String,
        position: Int
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let cleaned = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleaned.isEmpty else {
            return
        }

        struct Row: Encodable {
            let user_id: UUID
            let scholarship_id: UUID
            let title: String
            let position: Int
        }

        try await supabase
            .from("application_tasks")
            .insert(
                Row(
                    user_id: userId,
                    scholarship_id: scholarshipId,
                    title: cleaned,
                    position: position
                )
            )
            .execute()
    }

    static func deleteApplicationTask(
        taskId: UUID
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("application_tasks")
            .delete()
            .eq("id", value: taskId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
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

    static func uploadProfileAvatar(
        userId: UUID,
        imageData: Data
    ) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/profile.jpg"

        try await supabase.storage
            .from("avatars")
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: path)

        struct Row: Encodable {
            let avatar_url: String
            let updated_at: String
        }

        try await supabase
            .from("community_profiles")
            .update(
                Row(
                    avatar_url: publicURL.absoluteString,
                    updated_at: ISO8601DateFormatter()
                        .string(from: Date())
                )
            )
            .eq("id", value: userId.uuidString)
            .execute()

        return publicURL.absoluteString
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
