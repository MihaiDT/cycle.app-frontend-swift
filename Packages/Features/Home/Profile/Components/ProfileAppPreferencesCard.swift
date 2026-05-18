import SwiftUI

// MARK: - Profile App Preferences Card
//
// Four-row navigation card for the "Preferințe în aplicație" section.
// Each row reads as a "leads somewhere" affordance via ProfileNavChip.
// The card stays purely presentational — taps are forwarded as
// callbacks so ProfileFeature owns the routing.

public struct ProfileAppPreferencesCard: View {
    public let onTrackingTap: () -> Void
    public let onRemindersTap: () -> Void
    public let onSettingsTap: () -> Void

    public init(
        onTrackingTap: @escaping () -> Void,
        onRemindersTap: @escaping () -> Void,
        onSettingsTap: @escaping () -> Void
    ) {
        self.onTrackingTap = onTrackingTap
        self.onRemindersTap = onRemindersTap
        self.onSettingsTap = onSettingsTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(title: "Customize tracking", action: onTrackingTap)
            divider
            row(title: "Reminders & notifications", action: onRemindersTap)
            divider
            row(title: "Settings", action: onSettingsTap)
        }
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private func row(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(DesignColors.text)
                Spacer(minLength: 0)
                ProfileNavChip()
            }
            .padding(.horizontal, AppLayout.spacingM)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, AppLayout.spacingM)
    }
}
