import Foundation
import Supabase

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
