import SwiftUI

// MARK: - Unavailable State
//
// Rendered when the device doesn't support HealthKit (iPad without
// Health, Mac-Catalyst builds). No CTA — the user can't do anything
// to fix it, so we stay terse and informative.

struct BodySignalsUnavailableState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BodySignalsSectionHeader()
            Text("Body signals need an iPhone with Apple Health, which isn't available on this device.")
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
