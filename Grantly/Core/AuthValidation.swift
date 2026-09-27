import Foundation

enum AuthValidation {
    static func normalizedEmail(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func isValidEmail(_ value: String) -> Bool {
        let email = normalizedEmail(value)

        guard
            !email.isEmpty,
            email.count <= 254,
            let atIndex = email.lastIndex(of: "@"),
            atIndex != email.startIndex
        else {
            return false
        }

        let domainStart = email.index(after: atIndex)
        guard domainStart < email.endIndex else {
            return false
        }

        let local = email[..<atIndex]
        let domain = email[domainStart...]

        guard
            !local.isEmpty,
            domain.contains("."),
            !domain.hasPrefix("."),
            !domain.hasSuffix("."),
            !email.contains(" ")
        else {
            return false
        }

        return true
    }

    static func passwordIssue(_ password: String) -> String? {
        if password.count < 8 {
            return "Use at least 8 characters."
        }

        if password.count > 128 {
            return "Password is too long."
        }

        return nil
    }
}
