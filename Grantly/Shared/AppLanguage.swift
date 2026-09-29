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

struct LanguageFlagStrip: View {
    @AppStorage("grantly.language")
    private var language: AppLanguage = .english

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    language = option
                } label: {
                    Text(option.flag)
                        .font(.system(size: 21))
                        .frame(width: 34, height: 34)
                        .background(
                            language == option
                                ? Theme.surfaceRaised
                                : Color.clear
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    language == option
                                        ? Theme.accent.opacity(0.45)
                                        : Theme.ink.opacity(0.06),
                                    lineWidth: language == option ? 1.5 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.title))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
        )
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
