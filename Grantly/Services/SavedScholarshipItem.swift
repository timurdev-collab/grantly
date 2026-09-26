import Foundation

struct SavedScholarshipItem: Identifiable, Decodable {
    let scholarshipId: UUID
    let applicationStatus: String
    let notes: String?
    let scholarship: Scholarship

    var id: UUID {
        scholarshipId
    }

    enum CodingKeys: String, CodingKey {
        case scholarshipId = "scholarship_id"
        case applicationStatus = "application_status"
        case notes
        case scholarship = "scholarships"
    }
}
