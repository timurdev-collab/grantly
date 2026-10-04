import XCTest
@testable import EduT

final class AuthValidationTests: XCTestCase {
    func testEmailNormalization() {
        XCTAssertEqual(
            AuthValidation.normalizedEmail("  Student@Example.COM "),
            "student@example.com"
        )
    }

    func testValidEmailExamples() {
        XCTAssertTrue(
            AuthValidation.isValidEmail("student@example.com")
        )
        XCTAssertTrue(
            AuthValidation.isValidEmail("a.b+test@uni.edu")
        )
    }

    func testInvalidEmailExamples() {
        XCTAssertFalse(AuthValidation.isValidEmail(""))
        XCTAssertFalse(AuthValidation.isValidEmail("student"))
        XCTAssertFalse(AuthValidation.isValidEmail("@example.com"))
        XCTAssertFalse(AuthValidation.isValidEmail("user@example"))
        XCTAssertFalse(
            AuthValidation.isValidEmail("user @example.com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail("a@b@c.com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail(".user@example.com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail("user.@example.com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail("user..name@example.com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail("user@example..com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail("user@-example.com")
        )
        XCTAssertFalse(
            AuthValidation.isValidEmail("user@example-.com")
        )
    }

    func testPasswordLengthValidation() {
        XCTAssertNotNil(AuthValidation.passwordIssue("1234567"))
        XCTAssertNil(AuthValidation.passwordIssue("12345678"))
        XCTAssertNotNil(
            AuthValidation.passwordIssue(String(repeating: "a", count: 129))
        )
    }
}
