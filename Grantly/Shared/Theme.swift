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
    // Neutral-first palette: warm cream and white surfaces with forest green used as a focused accent.
    private static func adaptive(
        light: UInt32,
        dark: (CGFloat, CGFloat, CGFloat),
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(
                    red: dark.0,
                    green: dark.1,
                    blue: dark.2,
                    alpha: darkAlpha
                )
            }

            return UIColor(
                red: CGFloat((light >> 16) & 255) / 255,
                green: CGFloat((light >> 8) & 255) / 255,
                blue: CGFloat(light & 255) / 255,
                alpha: 1
            )
        })
    }

    // Core neutral surfaces
    static let navyDeep = adaptive(
        light: 0xFBF8F1,
        dark: (0.055, 0.071, 0.066)
    )
    static let navy = adaptive(
        light: 0xF4EEE4,
        dark: (0.075, 0.094, 0.086)
    )
    static let surface = adaptive(
        light: 0xFFFFFF,
        dark: (0.094, 0.114, 0.104)
    )
    static let surfaceRaised = adaptive(
        light: 0xF2ECE2,
        dark: (0.122, 0.145, 0.132)
    )

    // Typography
    static let ink = adaptive(
        light: 0x24342E,
        dark: (0.956, 0.941, 0.902)
    )
    static let muted = adaptive(
        light: 0x6C756F,
        dark: (0.956, 0.941, 0.902),
        darkAlpha: 0.68
    )

    // Brand accents
    static let accent = adaptive(
        light: 0x244636,
        dark: (0.733, 0.824, 0.753)
    )
    static let accentSoft = adaptive(
        light: 0x577261,
        dark: (0.835, 0.875, 0.824)
    )
    static let onAccent = adaptive(
        light: 0xFFFDF8,
        dark: (0.055, 0.071, 0.066)
    )

    // Supporting tones
    static let green = adaptive(
        light: 0x6B806F,
        dark: (0.565, 0.714, 0.608)
    )
    static let sand = adaptive(
        light: 0xC9AE7B,
        dark: (0.765, 0.682, 0.514)
    )
    static let beige = adaptive(
        light: 0xE8DDCD,
        dark: (0.204, 0.220, 0.204)
    )
    static let danger = adaptive(
        light: 0xB13A43,
        dark: (1.0, 0.36, 0.40)
    )

    // Legacy aliases kept so the rest of the app inherits the refreshed palette.
    static let blue = accent
    static let blueSoft = accentSoft
    static let sky = adaptive(
        light: 0x6C7F73,
        dark: (0.690, 0.788, 0.706)
    )
    static let orange = sand
    static let orangeSoft = adaptive(
        light: 0xA98955,
        dark: (0.816, 0.719, 0.549)
    )
    static let white = ink
    static let parchment = ink
    static let ivory = navyDeep
    static let brass = sand
    static let brassSoft = orangeSoft
    static let oxblood = danger
    static let forest = accent
    static let sage = adaptive(
        light: 0xDDE6DF,
        dark: (0.175, 0.220, 0.193)
    )
    static let mist = surfaceRaised
    static let violet = accent
    static let soft = surfaceRaised
    static let mint = sage

    static let pageBackground = navyDeep
    static let cardBackground = surface

    static let heroGradient = LinearGradient(
        colors: [surface, navy],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let gradientStart = adaptive(
        light: 0x6B806F,
        dark: (0.835, 0.875, 0.824)
    )

    static let orangeGradient = LinearGradient(
        colors: [sand, orangeSoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let blueGradient = LinearGradient(
        colors: [gradientStart, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let paperGradient = LinearGradient(
        colors: [surface, surfaceRaised],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func serifTitle(
        _ size: CGFloat,
        weight: Font.Weight = .semibold
    ) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
