import Foundation

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
}
