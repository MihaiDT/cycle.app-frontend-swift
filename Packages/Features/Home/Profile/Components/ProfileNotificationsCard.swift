import SwiftUI

// MARK: - Profile Notifications Card
//
// Toggle for the daily check-in reminder + a time row that opens the
// DS DatePickerSheet (.hourAndMinute) when the toggle is on. The
// toggle binding is a Toggle so iOS animates the row in/out cleanly;
// state mutations / notification scheduling happen in ProfileFeature.

public struct ProfileNotificationsCard: View {
    public let isOn: Bool
    public let reminderTime: Date
    public let onToggle: (Bool) -> Void
    public let onReminderRowTap: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    public init(
        isOn: Bool,
        reminderTime: Date,
        onToggle: @escaping (Bool) -> Void,
        onReminderRowTap: @escaping () -> Void
    ) {
        self.isOn = isOn
        self.reminderTime = reminderTime
        self.onToggle = onToggle
        self.onReminderRowTap = onReminderRowTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(get: { isOn }, set: onToggle)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily check-in reminder")
                        .font(AppTypography.rowTitle)
                        .foregroundStyle(DesignColors.text)
                    Text("A gentle nudge to log how you feel.")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }
            .tint(DesignColors.accentWarm)
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)

            if isOn {
                Rectangle()
                    .fill(DesignColors.textSecondary.opacity(0.12))
                    .frame(height: 0.5)
                    .padding(.horizontal, AppLayout.spacingM)

                Button(action: onReminderRowTap) {
                    HStack(spacing: 0) {
                        Text("Reminder time")
                            .font(AppTypography.rowTitle)
                            .foregroundStyle(DesignColors.text)
                        Spacer()
                        Text(Self.timeFormatter.string(from: reminderTime))
                            .font(AppTypography.rowTitleEmphasized)
                            .foregroundStyle(DesignColors.accentWarm)
                            .padding(.trailing, AppLayout.spacingM)
                        ProfileNavChip()
                    }
                    .padding(.horizontal, AppLayout.spacingM)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL, rasterize: false)
    }
}
