import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthStore {
    var userId: UUID?
    var isLoading = true
    var errorMessage: String?

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

    func signIn(email: String, password: String) async -> Bool {
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
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

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        userId = nil
    }
}
