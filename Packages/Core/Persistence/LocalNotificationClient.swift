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
    /// Schedule a single one-off notification (e.g. challenge snooze,
    /// "remind me later today"). Replaces any existing notification with
    /// the same identifier so the latest snooze wins.
    public var scheduleOneOff: @Sendable (_ id: String, _ title: String, _ body: String, _ after: TimeInterval) async throws -> Void
    /// Cancel a specific pending notification by identifier (no-op if it
    /// doesn't exist). Use when the user completes / skips the action
    /// that a prior snooze was reminding them of.
    public var cancelOneOff: @Sendable (_ id: String) async -> Void
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
            scheduleOneOff: { id, title, body, after in
                await MainActor.run {
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: [id])
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, after),
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: trigger
                )

                try await UNUserNotificationCenter.current().add(request)
            },
            cancelOneOff: { id in
                await MainActor.run {
                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: [id])
                }
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
            scheduleOneOff: { _, _, _, _ in },
            cancelOneOff: { _ in },
            cancelAll: { },
            isAuthorized: { false }
        )
    }
}
