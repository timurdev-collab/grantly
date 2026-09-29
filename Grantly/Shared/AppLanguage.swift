import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case vietnamese = "vi"
    case arabic = "ar"
    case chinese = "zh-Hans"
    case french = "fr"
    case spanish = "es"
    case german = "de"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var isRightToLeft: Bool {
        self == .arabic
    }

    var title: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .vietnamese: return "Tiếng Việt"
        case .arabic: return "العربية"
        case .chinese: return "中文"
        case .french: return "Français"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        case .vietnamese: return "🇻🇳"
        case .arabic: return "🇸🇦"
        case .chinese: return "🇨🇳"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        }
    }
}

struct LanguageFlagMenu: View {
    @AppStorage("grantly.language")
    private var language: AppLanguage = .english

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    language = option
                } label: {
                    HStack {
                        Text("\(option.flag) \(option.title)")
                        if language == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(language.flag)
                .font(.system(size: 22))
                .frame(width: 42, height: 42)
                .background(Theme.surface)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Language"))
        .accessibilityValue(Text(language.title))
    }
}


enum L10n {
    static var language: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "grantly.language") ?? AppLanguage.english.rawValue
        return AppLanguage(rawValue: raw) ?? .english
    }

    static func string(_ key: String) -> String {
        guard
            let path = Bundle.main.path(
                forResource: language.localeIdentifier,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return key
        }

        return bundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: Locale(identifier: language.localeIdentifier),
            arguments: arguments
        )
    }
}
