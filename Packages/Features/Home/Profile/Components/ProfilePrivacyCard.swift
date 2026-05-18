import SwiftUI

// MARK: - Profile Privacy Card
//
// Static reassurance copy + a HealthKit row whose tap behavior depends
// on the current authorization probe state. We never revoke from the
// app — when access is already granted, the row deep-links into iOS
// Settings so the user can revoke there.

public struct ProfilePrivacyCard: View {
    public let probe: BodySignalsAuthProbe
    public let onHealthKitTap: () -> Void

    public init(probe: BodySignalsAuthProbe, onHealthKitTap: @escaping () -> Void) {
        self.probe = probe
        self.onHealthKitTap = onHealthKitTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onHealthKitTap) {
                HStack(spacing: AppLayout.spacingS) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignColors.accentWarm)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Health data (Apple Health)")
                            .font(.raleway("Medium", size: 17, relativeTo: .headline))
                            .foregroundStyle(DesignColors.text)
                        Text(probeSubtitle)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(DesignColors.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if probe != .unavailable {
                        ProfileNavChip()
                    }
                }
                .padding(.horizontal, AppLayout.spacingM)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(probe == .unavailable)
        }
        .widgetCardStyle(cornerRadius: AppLayout.cornerRadiusL)
    }

    private var probeSubtitle: String {
        switch probe {
        case .unavailable: "Not available on this device"
        case .needsPrompt: "Tap to connect"
        case .canProceed:  "Manage in Settings"
        }
    }
}
