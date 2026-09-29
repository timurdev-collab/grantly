import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum Theme {
    // Dark mode uses deep forest green with cream text; light mode uses warm cream with dark green accents.
    private static func adaptive(light: UInt32, dark: (CGFloat, CGFloat, CGFloat), darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: dark.0, green: dark.1, blue: dark.2, alpha: darkAlpha)
            }
            let hex = light
            return UIColor(
                red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255,
                alpha: 1
            )
        })
    }

    static let navyDeep = adaptive(light: 0xF7F1E4, dark: (0.020, 0.118, 0.094))
    static let navy = adaptive(light: 0xEFE6D6, dark: (0.039, 0.180, 0.145))
    static let surface = adaptive(light: 0xFFF9EE, dark: (0.055, 0.220, 0.176))
    static let surfaceRaised = adaptive(light: 0xEFE4D2, dark: (0.082, 0.263, 0.212))
    static let ink = adaptive(light: 0x102E27, dark: (0.965, 0.941, 0.886))
    static let muted = adaptive(light: 0x3E5C54, dark: (0.965, 0.941, 0.886), darkAlpha: 0.68)
    static let accent = adaptive(light: 0x184636, dark: (0.776, 0.847, 0.737))
    static let accentSoft = adaptive(light: 0x245542, dark: (0.859, 0.894, 0.808))
    static let onAccent = adaptive(light: 0xFFF9EE, dark: (0.020, 0.118, 0.094))
    static let green = adaptive(light: 0x245542, dark: (0.541, 0.722, 0.624))
    static let danger = adaptive(light: 0xB32D39, dark: (1, 0.28, 0.34))

    // Legacy names remain aliases so every feature adopts the same palette.
    static let blue = accent
    static let blueSoft = accentSoft
    static let sky = adaptive(light: 0x2B5D49, dark: (0.741, 0.839, 0.737))
    static let orange = accent
    static let orangeSoft = accentSoft
    static let white = ink
    static let parchment = ink
    static let ivory = navyDeep
    static let brass = accent
    static let brassSoft = accentSoft
    static let oxblood = danger
    static let forest = green
    static let sage = green.opacity(0.16)
    static let mist = surfaceRaised
    static let violet = accent
    static let soft = surfaceRaised
    static let mint = green.opacity(0.16)
    static let pageBackground = navyDeep
    static let cardBackground = surface

    static let heroGradient = LinearGradient(colors: [surfaceRaised, navy], startPoint: .topLeading, endPoint: .bottomTrailing)
    private static let gradientStart = adaptive(light: 0x245542, dark: (0.859, 0.894, 0.808))
    static let orangeGradient = LinearGradient(colors: [gradientStart, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let blueGradient = orangeGradient
    static let paperGradient = LinearGradient(colors: [surfaceRaised, surface], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
