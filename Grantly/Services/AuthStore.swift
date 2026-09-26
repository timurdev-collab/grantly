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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
                errorMessage = "Your account could not be deleted."
                return false
            }

            try? await supabase.auth.signOut()
            UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
            needsPasswordReset = false
            userId = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        UserDefaults.standard.removeObject(forKey: recoveryFlagKey)
        needsPasswordReset = false
        userId = nil
    }
}
