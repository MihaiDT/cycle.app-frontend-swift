import SwiftUI

/// Clinical safety screen pushed from the "When to see a
/// doctor" footer row on Body Patterns. Lists thresholds drawn
/// verbatim from public guidance (NHS, CDC, ACOG, Mayo, NICE)
/// with source attribution on every row.
///
/// Two visual buckets:
///   * Routine consultation — `ClinicalThresholdRow` list,
///     calm tone, "book an appointment".
///   * Urgent / emergency — `EmergencyCallout`, high-contrast
///     filled card, explicit "call 911 / 999 / 112" footer.
///
/// Apple Review Guideline 1.4.1 specifically calls out apps
/// that may provide medical information; this screen is the
/// "remind users to check with a doctor" surface for the
/// Body Patterns flow.
struct WhenToSeeDoctorScreen: View {
    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AppScreenHeader(
                        eyebrow: "Medical Safety",
                        title: "When to see a doctor"
                    )

                    MedicalAdvisoryBanner(
                        message: "These guidelines come from public clinical sources. They are not a substitute for talking to your own clinician, who knows your full history."
                    )

                    routineSection
                    emergencyCallout
                    trustSection

                    SourceCitationFooter(
                        sources: ["ACOG", "NHS", "Mayo Clinic", "CDC", "NICE"]
                    )
                    .padding(.top, 4)

                    MedicalDeviceDisclaimer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Body Patterns")
                    .font(AppTypography.rowTitleEmphasized)
                    .foregroundStyle(DesignColors.text)
            }
        }
    }

    // MARK: - Routine consultation

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Book an appointment if")
                .font(.raleway("Bold", size: 18, relativeTo: .title3))
                .foregroundStyle(DesignColors.text)

            VStack(alignment: .leading, spacing: 14) {
                ClinicalThresholdRow(
                    glyph: "drop",
                    text: "Your period lasts longer than 7 days.",
                    source: "CDC"
                )
                ClinicalThresholdRow(
                    glyph: "drop.fill",
                    text: "You change a pad or tampon more often than every 2 hours.",
                    source: "CDC"
                )
                ClinicalThresholdRow(
                    glyph: "circle.fill",
                    text: "You pass blood clots larger than a 10p coin (about 2.5 cm).",
                    source: "NHS"
                )
                ClinicalThresholdRow(
                    glyph: "calendar.badge.exclamationmark",
                    text: "You've missed three periods in a row.",
                    source: "NHS"
                )
                ClinicalThresholdRow(
                    glyph: "bolt.heart",
                    text: "Pain is severe enough to keep you from your normal day.",
                    source: "NHS"
                )
                ClinicalThresholdRow(
                    glyph: "calendar",
                    text: "You bleed between periods or after sex.",
                    source: "NHS"
                )
                ClinicalThresholdRow(
                    glyph: "exclamationmark.triangle",
                    text: "You experience any vaginal bleeding after menopause.",
                    source: "NICE"
                )
                ClinicalThresholdRow(
                    glyph: "wind",
                    text: "PMS makes daily life hard, or lifestyle changes haven't helped.",
                    source: "NHS"
                )
                ClinicalThresholdRow(
                    glyph: "heart.text.square",
                    text: "You feel very anxious, angry, depressed, or have thoughts of suicide around your period.",
                    source: "NHS"
                )
            }
        }
    }

    // MARK: - Emergency

    private var emergencyCallout: some View {
        EmergencyCallout(
            title: "Get help now if",
            items: [
                "You soak through a pad every hour for 2 hours in a row, especially with chest pain, shortness of breath, dizziness, or fainting.",
                "You're pregnant and bleeding heavily, or have severe belly pain, shoulder-tip pain, or feel faint.",
                "Sudden severe pain on one side of your belly, with shoulder-tip pain or a positive pregnancy test.",
            ],
            footer: "Call your local emergency number (911 / 999 / 112) or go to the nearest emergency department."
        )
    }

    // MARK: - Trust your body

    private var trustSection: some View {
        EducationalSection(
            eyebrow: "Trust your body",
            paragraph: "This list isn't exhaustive. If something feels off – even if it's not on this list – book a visit. You know your normal."
        )
    }

    // Disclaimer now provided by the shared
    // `MedicalDeviceDisclaimer` component — see the callsite
    // above for the actual placement.
}
