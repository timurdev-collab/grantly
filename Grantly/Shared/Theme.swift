import SwiftUI

enum Theme {
    // Approved Grantly direction: deep navy + vivid orange.
    static let navy = Color(red: 0.015, green: 0.070, blue: 0.135)
    static let navyDeep = Color(red: 0.008, green: 0.038, blue: 0.080)
    static let surface = Color(red: 0.035, green: 0.105, blue: 0.185)
    static let surfaceRaised = Color(red: 0.055, green: 0.135, blue: 0.225)
    static let orange = Color(red: 1.00, green: 0.37, blue: 0.055)
    static let orangeSoft = Color(red: 1.00, green: 0.55, blue: 0.18)
    static let sky = Color(red: 0.22, green: 0.64, blue: 1.00)
    static let white = Color.white
    static let muted = Color.white.opacity(0.62)
    static let green = Color(red: 0.22, green: 0.84, blue: 0.58)

    // Compatibility aliases for existing views while the design system
    // transitions away from the previous academic/vintage palette.
    static let ink = Color.white
    static let parchment = Color.white
    static let ivory = navy
    static let brass = orange
    static let brassSoft = orangeSoft
    static let oxblood = orange
    static let forest = green
    static let sage = green.opacity(0.16)
    static let mist = surfaceRaised
    static let violet = orange
    static let soft = surfaceRaised
    static let mint = green.opacity(0.16)

    static let pageBackground = navyDeep
    static let cardBackground = surface

    static let heroGradient = LinearGradient(
        colors: [surfaceRaised, navy],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let orangeGradient = LinearGradient(
        colors: [orangeSoft, orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let paperGradient = LinearGradient(
        colors: [surfaceRaised, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Kept for source compatibility; now deliberately modern sans-serif.
    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
