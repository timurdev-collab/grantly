import XCTest

final class OnboardingLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSingleWelcomePageAndSignInRemainReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let primary = app.buttons["onboarding.primary"]
        let signIn = app.buttons["onboarding.signIn"]

        XCTAssertTrue(primary.waitForExistence(timeout: 20))
        XCTAssertTrue(primary.isHittable, "Get started must be reachable on the single welcome page")
        XCTAssertTrue(signIn.isHittable, "Returning users must be able to sign in")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(primary.frame), "Primary control must fit on screen")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(signIn.frame), "Sign-in control must fit on screen")
        capture("Onboarding-single-page")

        signIn.tap()
        XCTAssertTrue(app.staticTexts["auth.login.title"].waitForExistence(timeout: 10))
        capture("Sign-in")
    }

    @MainActor
    func testGetStartedOpensAccountCreation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20))
        XCTAssertTrue(primary.isHittable)
        primary.tap()
        XCTAssertTrue(app.staticTexts["Create your account"].waitForExistence(timeout: 10))
        capture("Create-account")
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
        let signIn = app.buttons["onboarding.signIn"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20))
        XCTAssertTrue(primary.isHittable, "Get started must remain accessible with large text")
        XCTAssertTrue(signIn.isHittable, "Sign in must remain accessible with large text")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(signIn.frame), "The complete sign-in control must fit on screen")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(primary.frame), "The complete primary control must fit on screen")
        capture("Onboarding-large-text")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
