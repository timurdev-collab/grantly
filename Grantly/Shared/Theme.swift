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
    // Semantic colors resolve against the view's current appearance.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255,
                alpha: 1
            )
        })
    }

    static let navyDeep = adaptive(light: 0xF7F1E7, dark: 0x081B38)
    static let navy = adaptive(light: 0xF0E7DA, dark: 0x0B2345)
    static let surface = adaptive(light: 0xFFFCF6, dark: 0x10294A)
    static let surfaceRaised = adaptive(light: 0xEFE4D5, dark: 0x163456)
    static let ink = adaptive(light: 0x493023, dark: 0xFFFFFF)
    static let muted = adaptive(light: 0x745B4B, dark: 0xAABBD0)
    static let accent = adaptive(light: 0x845B3C, dark: 0x0866FF)
    static let accentSoft = adaptive(light: 0x795134, dark: 0x6BA6FF)
    static let onAccent = Color.white
    static let green = adaptive(light: 0x246B48, dark: 0x29D18C)
    static let danger = adaptive(light: 0xB32D39, dark: 0xFF4757)

    // Legacy names remain aliases so every feature adopts the same palette.
    static let blue = accent
    static let blueSoft = accentSoft
    static let sky = accentSoft
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
    static let orangeGradient = LinearGradient(colors: [accent, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let blueGradient = orangeGradient
    static let paperGradient = LinearGradient(colors: [surfaceRaised, surface], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
