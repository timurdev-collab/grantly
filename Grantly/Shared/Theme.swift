import SwiftUI

enum Theme {
    // Grantly's visual language is inspired by old university libraries:
    // ink, parchment, brass and oxblood rather than generic startup purple.
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.10)
    static let navy = Color(red: 0.075, green: 0.12, blue: 0.18)
    static let parchment = Color(red: 0.965, green: 0.945, blue: 0.90)
    static let ivory = Color(red: 0.992, green: 0.985, blue: 0.965)
    static let brass = Color(red: 0.69, green: 0.52, blue: 0.24)
    static let brassSoft = Color(red: 0.93, green: 0.87, blue: 0.74)
    static let oxblood = Color(red: 0.40, green: 0.08, blue: 0.10)
    static let forest = Color(red: 0.10, green: 0.31, blue: 0.24)
    static let sage = Color(red: 0.86, green: 0.91, blue: 0.86)
    static let mist = Color(red: 0.925, green: 0.935, blue: 0.94)

    // Compatibility aliases used by older screens.
    static let violet = brass
    static let soft = mist
    static let mint = sage
    static let green = forest

    static let pageBackground = ivory
    static let cardBackground = Color.white

    static let heroGradient = LinearGradient(
        colors: [navy, ink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let paperGradient = LinearGradient(
        colors: [Color.white, parchment.opacity(0.62)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
