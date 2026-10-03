import XCTest
@testable import EduT

final class AppDateParserTests: XCTestCase {
    func testParsesStandardISO8601Timestamp() {
        XCTAssertNotNil(
            AppDateParser.date(from: "2026-10-03T12:34:56Z")
        )
    }

    func testParsesFractionalISO8601Timestamp() {
        XCTAssertNotNil(
            AppDateParser.date(from: "2026-10-03T12:34:56.123456Z")
        )
    }

    func testRejectsInvalidTimestamp() {
        XCTAssertNil(AppDateParser.date(from: "not-a-date"))
    }
}
