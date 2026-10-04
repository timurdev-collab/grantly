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
            email.filter({ $0 == "@" }).count == 1,
            let atIndex = email.firstIndex(of: "@"),
            atIndex != email.startIndex
        else {
            return false
        }

        let domainStart = email.index(after: atIndex)
        guard domainStart < email.endIndex else {
            return false
        }

        let local = String(email[..<atIndex])
        let domain = String(email[domainStart...])

        guard
            local.count <= 64,
            !local.hasPrefix("."),
            !local.hasSuffix("."),
            !local.contains(".."),
            domain.contains("."),
            !domain.hasPrefix("."),
            !domain.hasSuffix("."),
            !domain.contains(".."),
            !email.contains(where: { $0.isWhitespace })
        else {
            return false
        }

        let labels = domain.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        guard
            labels.count >= 2,
            labels.allSatisfy({ label in
                !label.isEmpty &&
                label.count <= 63 &&
                label.first != "-" &&
                label.last != "-" &&
                label.allSatisfy { character in
                    character.isLetter ||
                    character.isNumber ||
                    character == "-"
                }
            })
        else {
            return false
        }

        let localPattern = "^[A-Za-z0-9.!#$%&'*+/=?^_{|}~-]+$"
        return local.range(
            of: localPattern,
            options: .regularExpression
        ) != nil
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
