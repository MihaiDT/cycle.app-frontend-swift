import SwiftUI

// MARK: - Prompt State
//
// Shown when at least one of our HealthKit types is `.notDetermined`
// — the user has never been asked. Mirrors the editorial title
// hierarchy used by `CycleTrendCard` / `CycleHistoryCard` on the
// same screen: big stacked "YOUR BODY" on the left, a small brand
// anchor (Apple Health heart) in the top-right corner, a subtitle
// row beneath the title, description paragraph, and CTA.

struct BodySignalsPromptState: View {
    let onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            description
            enableButton
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DesignColors.textSecondary)
                    Text("YOUR BODY")
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                        .tracking(1.4)
                        .foregroundStyle(DesignColors.textSecondary)
                }

                Text("Connect your Apple Watch")
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
        Text("We'll read wrist temperature, HRV, and resting heart rate from Apple Health to show how your body moves through each phase. Stays on your device.")
            .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
            .foregroundStyle(DesignColors.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var enableButton: some View {
        HeroGlassCapsuleButton("Sync with Apple", layout: .wide, action: onEnable)
            .accessibilityHint("Opens the Apple Health connect sheet")
    }
}
