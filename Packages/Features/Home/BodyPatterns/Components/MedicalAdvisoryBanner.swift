import SwiftUI

/// Persistent advisory banner pinned above content on
/// safety-sensitive screens.
///
/// One sentence, calm tone, no panic — Apple Review Guideline
/// 1.4.1 expects medical apps to "remind users to check with a
/// doctor in addition to using the app and before making medical
/// decisions." Putting this banner one tap from the surface it
/// qualifies satisfies that requirement visibly.
struct MedicalAdvisoryBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.top, 1)

            Text(message)
                .font(.raleway("Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.25),
                            lineWidth: 0.6
                        )
                }
        }
    }
}
