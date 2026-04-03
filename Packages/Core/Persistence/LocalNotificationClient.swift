import ComposableArchitecture
import Foundation
import UserNotifications

// MARK: - Local Notification Client

/// Schedules daily check-in reminders using UNUserNotificationCenter.
/// No server needed — runs entirely on device.
public struct LocalNotificationClient: Sendable {
    /// Request notification permission from the user.
    public var requestAuthorization: @Sendable () async throws -> Bool
    /// Schedule a repeating daily check-in reminder.
    public var scheduleDailyReminder: @Sendable (Int, Int) async throws -> Void
    /// Cancel all scheduled reminders.
    public var cancelAll: @Sendable () async -> Void
    /// Check if notifications are currently authorized.
    public var isAuthorized: @Sendable () async -> Bool
}

// MARK: - Dependency

extension LocalNotificationClient: DependencyKey {
    public static let liveValue = LocalNotificationClient.live()
    public static let testValue = LocalNotificationClient.mock()
    public static let previewValue = LocalNotificationClient.mock()
}

extension DependencyValues {
    public var localNotifications: LocalNotificationClient {
        get { self[LocalNotificationClient.self] }
        set { self[LocalNotificationClient.self] = newValue }
    }
}

// MARK: - Live

extension LocalNotificationClient {
    static let dailyReminderID = "cycle.dailyCheckin"

    static func live() -> Self {
        LocalNotificationClient(
            requestAuthorization: {
                try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
            },
            scheduleDailyReminder: { hour, minute in
                await MainActor.run {
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
                }

                let content = UNMutableNotificationContent()
                content.title = "Daily Check-in"
                content.body = "Take a moment to check in with yourself today"
                content.sound = .default

                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )

                let request = UNNotificationRequest(
                    identifier: dailyReminderID,
                    content: content,
                    trigger: trigger
                )

                try await UNUserNotificationCenter.current().add(request)
            },
            cancelAll: {
                await MainActor.run {
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
                }
            },
            isAuthorized: {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                return settings.authorizationStatus == .authorized
            }
        )
    }
}

// MARK: - Mock

extension LocalNotificationClient {
    static func mock() -> Self {
        LocalNotificationClient(
            requestAuthorization: { true },
            scheduleDailyReminder: { _, _ in },
            cancelAll: { },
            isAuthorized: { false }
        )
    }
}
