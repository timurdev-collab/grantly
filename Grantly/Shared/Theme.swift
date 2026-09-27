import SwiftUI

enum Theme {
    // Grantly direction: deep navy foundation with warm orange accents.
    static let navyDeep = Color(red: 0.004, green: 0.027, blue: 0.055)
    static let navy = Color(red: 0.010, green: 0.055, blue: 0.105)
    static let surface = Color(red: 0.026, green: 0.083, blue: 0.145)
    static let surfaceRaised = Color(red: 0.045, green: 0.115, blue: 0.185)

    static let blue = Color(red: 0.08, green: 0.39, blue: 0.72)
    static let blueSoft = Color(red: 0.34, green: 0.58, blue: 0.82)
    static let sky = Color(red: 0.40, green: 0.66, blue: 0.88)
    static let orange = Color(red: 1.00, green: 0.47, blue: 0.12)
    static let orangeSoft = Color(red: 1.00, green: 0.67, blue: 0.34)
    static let green = Color(red: 0.16, green: 0.82, blue: 0.55)
    static let danger = Color(red: 1.00, green: 0.28, blue: 0.34)

    static let white = Color.white
    static let muted = Color.white.opacity(0.62)

    // Compatibility aliases used by the existing feature screens.
    static let ink = Color.white
    static let parchment = Color.white
    static let ivory = navyDeep
    static let brass = orange
    static let brassSoft = orangeSoft
    static let oxblood = danger
    static let forest = green
    static let sage = green.opacity(0.16)
    static let mist = surfaceRaised
    static let violet = blue
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

    static let blueGradient = LinearGradient(
        colors: [blueSoft, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let paperGradient = LinearGradient(
        colors: [surfaceRaised, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
