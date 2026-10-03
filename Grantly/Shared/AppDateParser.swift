import Foundation

enum AppDateParser {
    private static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    private static let standardISO8601 = ISO8601DateFormatter()

    static func date(from value: String) -> Date? {
        fractionalISO8601.date(from: value) ??
        standardISO8601.date(from: value)
    }
}
