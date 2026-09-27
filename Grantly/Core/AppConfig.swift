import Foundation

enum AppEnvironment: String {
    case staging
    case production
}

enum AppConfig {
    static let environment: AppEnvironment = {
        let value = configurationValue("APP_ENVIRONMENT") ?? "production"
        return AppEnvironment(rawValue: value.lowercased()) ?? .production
    }()

    static let supabaseURL: URL = {
        guard
            let raw = configurationValue("SUPABASE_URL"),
            let url = URL(string: raw),
            ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            fatalError("Missing or invalid SUPABASE_URL build configuration")
        }

        return url
    }()

    static let supabasePublishableKey: String = {
        guard
            let key = configurationValue("SUPABASE_PUBLISHABLE_KEY"),
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fatalError("Missing SUPABASE_PUBLISHABLE_KEY build configuration")
        }

        return key
    }()

    static func configurationValue(_ key: String) -> String? {
        guard let raw = Bundle.main.object(
            forInfoDictionaryKey: key
        ) as? String else {
            return nil
        }

        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !value.isEmpty,
            !value.hasPrefix("$(")
        else {
            return nil
        }

        return value
    }
}
