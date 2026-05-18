import SwiftUI

/// Educational explainer pushed from the "How patterns work"
/// footer row on Body Patterns. Walks through the algorithm
/// (3-cycle confirmation, 2-cycle emerging, phase grouping)
/// and is explicit about what patterns are not — a diagnosis,
/// a prediction, or a substitute for a clinician.
///
/// Apple Review Guideline 1.4.1 requires medical apps to
/// "clearly disclose data and methodology to support accuracy
/// claims." This screen is that disclosure surface.
struct HowPatternsWorkScreen: View {
    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AppScreenHeader(
                        eyebrow: "Educational",
                        title: "How patterns work"
                    )

                    MedicalAdvisoryBanner(
                        message: "Patterns are observations, not medical advice."
                    )

                    EducationalSection(
                        eyebrow: "What we look for",
                        paragraph: "Body Patterns watches the symptoms you log across cycles and notices when something keeps showing up at the same moment in your hormonal rhythm – menstrual, follicular, ovulatory, or luteal.\n\nWhen the same symptom appears in the same phase across three full cycles, we call it a confirmed pattern. Two cycles? We mark it as emerging – something to keep an eye on."
                    )

                    EducationalSection(
                        eyebrow: "Why phases, not days",
                        paragraph: "Cycles vary. The follicular phase – the days between your period and ovulation – can range from about 10 to 16 days in healthy cycles. The luteal phase, from ovulation to your next period, usually sits around 12 to 14 days but varies more than people think.\n\nBecause your cycle isn't a fixed calendar, we group symptoms by phase, not by day-number. A migraine on day 14 of one cycle and day 17 of the next can be the same pattern."
                    )

                    EducationalSection(
                        eyebrow: "What patterns are not",
                        paragraph: "A pattern is a signal, not a diagnosis. We can tell you that nausea has shown up in your luteal phase three cycles running. We can't tell you why, and we won't try.\n\nIf a pattern surprises you, or you notice something new and intense, talk to a clinician. Your data, your context, your call."
                    )

                    EducationalSection(
                        eyebrow: "How to use them",
                        paragraph: "Patterns are most useful when shared. Take a screenshot, save the page, or open it in your appointment. The point isn't to label yourself – it's to walk into a conversation with your doctor better prepared than you would have been from memory alone."
                    )

                    SourceCitationFooter(
                        intro: "Phase definitions follow",
                        sources: ["ACOG", "NIH Endotext"]
                    )
                    .padding(.top, 4)
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
}
