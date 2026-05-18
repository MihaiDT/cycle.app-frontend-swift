import SwiftUI

// MARK: - Profile Account Card
//
// Logout + delete-account rows. Both ultimately route through
// HomeFeature.logoutTapped (which wipes every SwiftData model); the
// "delete" path additionally calls userProfileLocal.deleteProfile()
// up front and is gated by a confirmationDialog.

public struct ProfileAccountCard: View {
    public let onLogout: () -> Void
    public let onDeleteTapped: () -> Void
    public let onResetCycleData: () -> Void

    public init(
        onLogout: @escaping () -> Void,
        onDeleteTapped: @escaping () -> Void,
        onResetCycleData: @escaping () -> Void
    ) {
        self.onLogout = onLogout
        self.onDeleteTapped = onDeleteTapped
        self.onResetCycleData = onResetCycleData
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onLogout) {
                row(label: "Log out", tint: DesignColors.text, icon: "arrow.right.square")
            }
            .buttonStyle(.plain)

            divider

            Button(action: onResetCycleData) {
                row(label: "Reset cycle data", tint: DesignColors.text, icon: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)

            divider

            Button(role: .destructive, action: onDeleteTapped) {
                row(label: "Delete account", tint: DesignColors.accentWarm, icon: "trash")
            }
            .buttonStyle(.plain)
        }
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColors.textSecondary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, AppLayout.spacingM)
    }

    private func row(label: String, tint: Color, icon: String) -> some View {
        HStack(spacing: AppLayout.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint.opacity(0.85))
                .frame(width: 24)
            Text(label)
                .font(.raleway("Medium", size: 17, relativeTo: .headline))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, AppLayout.spacingM)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
