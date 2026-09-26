import Foundation

enum MatchingService {
    static func score(profile: StudentProfile, scholarship: Scholarship) -> ScholarshipMatch {
        var score = 35
        var reasons: [String] = []
        var blockers: [String] = []

        let gpaPercent: Double? = {
            guard let value = profile.gpaValue,
                  let scale = profile.gpaScale,
                  scale > 0 else { return nil }
            return value / scale * 100
        }()

        if let degree = profile.degreeLevel {
            if scholarship.degreeLevels.contains(degree) {
                score += 15
                reasons.append("Supports \(degree) study")
            } else {
                blockers.append("Degree level is not listed as eligible")
            }
        }

        let nationalities = scholarship.eligibleNationalities
        if nationalities.contains("ALL") ||
            (profile.nationality.map { nationalities.contains($0) } ?? false) {
            score += 10
            reasons.append("Nationality appears eligible")
        } else {
            blockers.append("Nationality is not listed as eligible")
        }

        if let minimum = scholarship.minGpaPercent, let current = gpaPercent {
            if current >= minimum {
                score += 12
                reasons.append("Meets the GPA threshold")
            } else {
                blockers.append("GPA is below the listed \(Int(minimum))% threshold")
            }
        } else if gpaPercent != nil {
            score += 4
        }

        if let minimum = scholarship.minIelts, let current = profile.ielts {
            if current >= minimum {
                score += 10
                reasons.append("Meets the IELTS threshold")
            } else {
                blockers.append("IELTS is below the listed \(minimum) threshold")
            }
        }

        if let major = profile.intendedMajor {
            let lower = major.lowercased()
            if scholarship.fields.contains("All fields") ||
                scholarship.fields.contains(where: {
                    $0.lowercased().contains(lower) || lower.contains($0.lowercased())
                }) {
                score += 8
                reasons.append("Academic field matches")
            }
        }

        let regionMatch = profile.targetRegions?.contains(where: {
            $0.caseInsensitiveCompare(scholarship.region) == .orderedSame
        }) ?? false
        let countryMatch = profile.targetCountries?.contains(where: {
            $0.caseInsensitiveCompare(scholarship.country) == .orderedSame
        }) ?? false

        if regionMatch || countryMatch {
            score += 6
            reasons.append("Matches a target destination")
        }

        if let income = profile.familyIncomeUSD,
           income <= 15_000,
           scholarship.fundingType.lowercased().contains("fully") {
            score += 4
            reasons.append("Strong funding fit")
        }

        let eligible = blockers.isEmpty
        if !eligible { score = min(score, 54) }

        return ScholarshipMatch(
            scholarship: scholarship,
            score: max(0, min(100, score)),
            eligible: eligible,
            reasons: reasons,
            blockers: blockers
        )
    }

    static func rank(profile: StudentProfile, scholarships: [Scholarship]) -> [ScholarshipMatch] {
        scholarships
            .map { score(profile: profile, scholarship: $0) }
            .sorted {
                if $0.eligible != $1.eligible { return $0.eligible && !$1.eligible }
                return $0.score > $1.score
            }
    }
}
