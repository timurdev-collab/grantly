import SwiftUI

enum Theme {
    // Grantly reference direction: midnight navy, electric blue and clean white.
    static let navyDeep = Color(red: 0.004, green: 0.027, blue: 0.055)
    static let navy = Color(red: 0.010, green: 0.055, blue: 0.105)
    static let surface = Color(red: 0.030, green: 0.095, blue: 0.165)
    static let surfaceRaised = Color(red: 0.055, green: 0.125, blue: 0.205)

    static let blue = Color(red: 0.025, green: 0.54, blue: 1.00)
    static let blueSoft = Color(red: 0.18, green: 0.68, blue: 1.00)
    static let sky = Color(red: 0.30, green: 0.76, blue: 1.00)
    static let green = Color(red: 0.16, green: 0.82, blue: 0.55)
    static let danger = Color(red: 1.00, green: 0.28, blue: 0.34)

    static let white = Color.white
    static let muted = Color.white.opacity(0.62)

    // Compatibility aliases used by the existing feature screens.
    // The old "orange/brass" names now resolve to the blue reference accent.
    static let ink = Color.white
    static let parchment = Color.white
    static let ivory = navyDeep
    static let orange = blue
    static let orangeSoft = blueSoft
    static let brass = blue
    static let brassSoft = blueSoft
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
        colors: [blueSoft, blue],
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
