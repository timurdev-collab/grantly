import XCTest

final class OnboardingLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingNavigationAndSignInRemainReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let primary = app.buttons["onboarding.primary"]
        let signIn = app.buttons["onboarding.signIn"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20))

        for page in 1...3 {
            XCTAssertTrue(primary.isHittable, "Primary action must remain reachable on page \(page)")
            XCTAssertTrue(signIn.isHittable, "Returning users must be able to sign in on every page")
            capture("Onboarding-\(page)")
            if page < 3 { primary.tap() }
        }

        signIn.tap()
        XCTAssertTrue(app.staticTexts["auth.login.title"].waitForExistence(timeout: 10))
        capture("Sign-in")
    }

    @MainActor
    func testLargeTextKeepsOnboardingActionsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20))
        for page in 1...3 {
            XCTAssertTrue(primary.isHittable)
            let signIn = app.buttons["onboarding.signIn"]
            XCTAssertTrue(signIn.isHittable)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(signIn.frame), "The complete sign-in control must fit on screen")
            XCTAssertTrue(app.windows.firstMatch.frame.contains(primary.frame), "The complete primary control must fit on screen")
            capture("Onboarding-large-text-\(page)")
            if page < 3 { primary.tap() }
        }
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
