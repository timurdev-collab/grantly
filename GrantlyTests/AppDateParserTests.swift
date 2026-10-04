import XCTest
@testable import EduT

final class AppDateParserTests: XCTestCase {
    func testParsesStandardISO8601Timestamp() {
        XCTAssertNotNil(
            AppDateParser.date(from: "2026-10-04T03:52:37Z")
        )
    }

    func testParsesFractionalISO8601Timestamp() {
        XCTAssertNotNil(
            AppDateParser.date(from: "2026-10-04T03:52:37.123456Z")
        )
    }

    func testRejectsInvalidTimestamp() {
        XCTAssertNil(
            AppDateParser.date(from: "not-a-date")
        )
    }
}
