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
    // Preserve the original midnight navy/electric blue dark palette; light stays cream/brown.
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

    static let navyDeep = adaptive(light: 0xF7F1E7, dark: (0.004, 0.027, 0.055))
    static let navy = adaptive(light: 0xF0E7DA, dark: (0.010, 0.055, 0.105))
    static let surface = adaptive(light: 0xFFFCF6, dark: (0.030, 0.095, 0.165))
    static let surfaceRaised = adaptive(light: 0xEFE4D5, dark: (0.055, 0.125, 0.205))
    static let ink = adaptive(light: 0x493023, dark: (1, 1, 1))
    static let muted = adaptive(light: 0x745B4B, dark: (1, 1, 1), darkAlpha: 0.62)
    static let accent = adaptive(light: 0x845B3C, dark: (0.025, 0.54, 1))
    static let accentSoft = adaptive(light: 0x795134, dark: (0.18, 0.68, 1))
    static let onAccent = Color.white
    static let green = adaptive(light: 0x246B48, dark: (0.16, 0.82, 0.55))
    static let danger = adaptive(light: 0xB32D39, dark: (1, 0.28, 0.34))

    // Legacy names remain aliases so every feature adopts the same palette.
    static let blue = accent
    static let blueSoft = accentSoft
    static let sky = adaptive(light: 0x795134, dark: (0.30, 0.76, 1))
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
    private static let gradientStart = adaptive(light: 0x845B3C, dark: (0.18, 0.68, 1))
    static let orangeGradient = LinearGradient(colors: [gradientStart, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let blueGradient = orangeGradient
    static let paperGradient = LinearGradient(colors: [surfaceRaised, surface], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
