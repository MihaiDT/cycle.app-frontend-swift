import SwiftUI
import UIKit

// MARK: - No Data State
//
// Rendered when HealthKit surfaced no samples for any of our three
// types. Two real causes look identical to the app for privacy
// reasons: HealthKit returns an empty result both when the user
// genuinely has no logged data AND when they denied the read
// permission. Apple deliberately doesn't let us tell those apart on
// read-only access, so the copy speaks to both situations and the
// CTA hands control back to the user via Settings, where they can
// flip individual data types on or off.

struct BodySignalsNoDataState: View {
    let phase: CyclePhase?
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            description
            manageButton
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                // Section title moved out — sectionWrap.
                EmptyView()

                Text("No watch data yet")
                    .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
            }

            Spacer(minLength: 8)

            Image("HealthIcon", bundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .saturation(0.55)
                .opacity(0.92)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                .accessibilityHidden(true)
        }
    }

    private var description: some View {
        Text("Wrist temperature, HRV, and resting heart rate aren't being shared with cycle.app yet. Tap below to walk through enabling them in Apple Health.")
            .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
            .foregroundStyle(DesignColors.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var manageButton: some View {
        HeroGlassCapsuleButton("Sync with Apple", layout: .wide, action: onManage)
            .accessibilityHint("Opens a guide for enabling Apple Health data types")
    }
}
