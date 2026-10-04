import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthStore {
    var userId: UUID?
    var isLoading = true
    var errorMessage: String?
    var needsPasswordReset = false

    private let recoveryFlagKey = "grantly.awaitingPasswordRecovery"

    init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.session
            userId = session.user.id
        } catch {
            userId = nil
        }
    }

    func handleDeepLink(_ url: URL) async {
        errorMessage = nil

        do {
            let session = try await supabase.auth.session(from: url)
            userId = session.user.id

            if UserDefaults.standard.bool(forKey: recoveryFlagKey) {
                needsPasswordReset = true
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
            needsPasswordReset = false
            userId = session.user.id
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func signUp(email: String, password: String) async -> Bool {
        errorMessage = nil

        do {
            _ = try await supabase.auth.signUp(
                email: email,
                password: password,
                redirectTo: URL(string: "grantly://login-callback")!
            )
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func requestPasswordReset(email: String) async -> Bool {
        errorMessage = nil

        do {
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "grantly://login-callback")!
            )
            UserDefaults.standard.set(true, forKey: recoveryFlagKey)
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func updateRecoveredPassword(_ password: String) async -> Bool {
        errorMessage = nil

        do {
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )
            UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
            needsPasswordReset = false
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func cancelPasswordReset() {
        UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
        needsPasswordReset = false
    }

    func deleteAccount() async -> Bool {
        errorMessage = nil

        struct DeleteAccountResponse: Decodable {
            let deleted: Bool
        }

        do {
            let response: DeleteAccountResponse = try await supabase.functions
                .invoke("delete-account")

            guard response.deleted else {
                errorMessage = L10n.string("Your account could not be deleted.")
                return false
            }

            try? await supabase.auth.signOut()
            UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
            needsPasswordReset = false
            userId = nil
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func signOut() async {
        errorMessage = nil

        do {
            try await supabase.auth.signOut()
            UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
            needsPasswordReset = false
            userId = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") {
            return L10n.string("The email or password is incorrect.")
        }

        if message.contains("email not confirmed") {
            return L10n.string("Confirm your email address before signing in.")
        }

        if message.contains("user already registered") {
            return L10n.string("An account already exists for this email.")
        }

        if message.contains("network") ||
            message.contains("offline") ||
            message.contains("internet") {
            return L10n.string("Check your internet connection and try again.")
        }

        if message.contains("rate limit") ||
            message.contains("too many requests") {
            return L10n.string("Too many attempts. Please wait a moment and try again.")
        }

        if message.contains("weak password") {
            return L10n.string("Choose a stronger password and try again.")
        }

        return L10n.string("Something went wrong. Please try again.")
    }
}
