import SwiftUI

// MARK: - Medical Device Disclaimer
//
// Apple-review-grade disclaimer footer used at the bottom of every
// educational / info screen across cycle.app (Body Patterns about,
// How patterns work, When to see a doctor, Cycle Stat info screens).
//
// Three stacked layers — exactly what App Store reviewers expect on
// a health-data surface (Guideline 1.4.1):
//   1. Caps eyebrow "NOT A MEDICAL DEVICE" — flags the disclaimer
//      visually so it can't be missed by skim readers.
//   2. Body paragraph naming the limits (no medical advice, no
//      diagnosis, no treatment) and the redirect path
//      ("consult a qualified healthcare professional").
//   3. Emergency callout in heavier weight — separates the
//      everyday "see your doctor" from the urgent "call 911"
//      escalation.
//
// One source of truth so the wording (and the legal posture) stays
// identical across every educational surface in the app.

struct MedicalDeviceDisclaimer: View {
    static let eyebrow = "Not a medical device"
    static let bodyText = "cycle.app is not a medical device and does not provide medical advice, diagnosis, or treatment. The information shown here is for personal awareness and educational context only. Always consult a qualified healthcare professional before making decisions about your health."
    static let emergencyText = "In an emergency, call your local emergency number."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(MedicalDeviceDisclaimer.eyebrow)
                .font(.raleway("Bold", size: 12, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(DesignColors.accentWarmText)
                .textCase(.uppercase)

            Text(MedicalDeviceDisclaimer.bodyText)
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(MedicalDeviceDisclaimer.emergencyText)
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 12)
    }
}
