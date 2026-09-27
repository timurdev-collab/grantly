import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken
            .map { String(format: "%02x", $0) }
            .joined()

        UserDefaults.standard.set(
            token,
            forKey: NotificationRegistration.deviceTokenKey
        )

        Task {
            await NotificationRegistration.syncStoredPushToken()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Push registration failed: \(error.localizedDescription)")
    }
}

enum NotificationRegistration {
    static let deviceTokenKey = "grantly.apns.device.token"

    static func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter
                .current()
                .requestAuthorization(
                    options: [.alert, .badge, .sound]
                )

            guard granted else { return }

            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }

            await syncStoredPushToken()
            await scheduleLocalApplicationReminders()
        } catch {
            print("Notification permission failed: \(error.localizedDescription)")
        }
    }

    static func syncStoredPushToken() async {
        guard let token = UserDefaults.standard.string(
            forKey: deviceTokenKey
        ) else {
            return
        }

        guard (try? await supabase.auth.session.user.id) != nil else {
            return
        }

        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif

        try? await DataService.registerPushDevice(
            token: token,
            environment: environment
        )
    }

    static func scheduleLocalApplicationReminders() async {
        guard let items = try? await DataService.savedScholarshipItems() else {
            return
        }

        let center = UNUserNotificationCenter.current()

        for item in items {
            let deadlineText =
                item.personalDeadline ??
                item.applicationDeadline ??
                item.scholarship.deadline

            guard let deadlineText,
                  let deadline = parseDate(deadlineText) else {
                continue
            }

            for daysBefore in [7, 3, 1, 0] {
                guard let fireDate = Calendar.current.date(
                    byAdding: .day,
                    value: -daysBefore,
                    to: deadline
                ),
                fireDate > Date() else {
                    continue
                }

                var components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: fireDate
                )

                components.hour = 9
                components.minute = 0

                let content = UNMutableNotificationContent()
                content.title = daysBefore == 0
                    ? "Scholarship deadline today"
                    : "Scholarship deadline approaching"

                content.body = daysBefore == 0
                    ? "\(item.scholarship.title) is due today."
                    : "\(item.scholarship.title) is due in \(daysBefore) days."

                content.sound = .default
                content.userInfo = [
                    "kind": "deadline",
                    "scholarship_id": item.scholarshipId.uuidString
                ]

                let request = UNNotificationRequest(
                    identifier:
                        "deadline-\(item.scholarshipId)-\(daysBefore)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: components,
                        repeats: false
                    )
                )

                try? await center.add(request)
            }

            guard let tasks = try? await DataService.applicationTasks(
                scholarshipId: item.scholarshipId
            ) else {
                continue
            }

            for task in tasks where task.completedAt == nil {
                guard let dueAt = task.dueAt,
                      let dueDate = ISO8601DateFormatter().date(
                        from: dueAt
                      ),
                      dueDate > Date() else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Application task due"
                content.body =
                    "\(task.title) for \(item.scholarship.title)"
                content.sound = .default
                content.userInfo = [
                    "kind": "task",
                    "scholarship_id": item.scholarshipId.uuidString,
                    "task_id": task.id.uuidString
                ]

                let request = UNNotificationRequest(
                    identifier: "task-\(task.id.uuidString)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: max(
                            dueDate.timeIntervalSinceNow,
                            1
                        ),
                        repeats: false
                    )
                )

                try? await center.add(request)
            }
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        if let date = formatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }
}

@main
struct GrantlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .tint(Theme.violet)
                .onOpenURL { url in
                    Task {
                        await auth.handleDeepLink(url)
                    }
                }
        }
    }
}
