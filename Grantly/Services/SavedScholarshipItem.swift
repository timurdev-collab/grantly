import Foundation

struct SavedScholarshipItem: Identifiable, Decodable {
    let scholarshipId: UUID
    let applicationStatus: String
    let notes: String?
    let applicationDeadline: String?
    let personalDeadline: String?
    let submittedAt: String?
    let interviewAt: String?
    let resultAt: String?
    let documentsComplete: Bool
    let reminderEnabled: Bool
    let applicationReference: String?
    let portalLastCheckedAt: String?
    let scholarship: Scholarship

    var id: UUID {
        scholarshipId
    }

    enum CodingKeys: String, CodingKey {
        case scholarshipId = "scholarship_id"
        case applicationStatus = "application_status"
        case notes
        case applicationDeadline = "application_deadline"
        case personalDeadline = "personal_deadline"
        case submittedAt = "submitted_at"
        case interviewAt = "interview_at"
        case resultAt = "result_at"
        case documentsComplete = "documents_complete"
        case reminderEnabled = "reminder_enabled"
        case applicationReference = "application_reference"
        case portalLastCheckedAt = "portal_last_checked_at"
        case scholarship = "scholarships"
    }
}
