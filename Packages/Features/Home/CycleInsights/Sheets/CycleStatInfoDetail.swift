import SwiftUI

// MARK: - Cycle Stat Info Detail
//
// Apple Health–style explainer opened from the Normality rows on
// Cycle Stats. No more parallax hero illustration — surfaces are
// data-first stacked cards with caps eyebrow headers, matching the
// rest of the Cycle Stats / Body Signals detail screens.
//
// Cards stacked on the warm peach screen background:
//   1. Personal reading — label + big value + status
//   2. About — what's typical, with optional pull-quote highlights
//   3. What can shift it — paragraph + bullets
//   4. When to check in with a provider — paragraph + bullets
//   5. Disclaimer footer

struct CycleStatInfoDetailView: View {
    let kind: CycleStatInfoKind
    let previousValue: String?
    let badge: CycleStatusBadge?
    let cycleLengthDays: Int?
    let bleedingDays: Int?
    let variationStdDev: Double?

    private let copy: CycleStatInfoCopy

    init(
        kind: CycleStatInfoKind,
        previousValue: String?,
        badge: CycleStatusBadge?,
        cycleLengthDays: Int? = nil,
        bleedingDays: Int? = nil,
        variationStdDev: Double? = nil
    ) {
        self.kind = kind
        self.previousValue = previousValue
        self.badge = badge
        self.cycleLengthDays = cycleLengthDays
        self.bleedingDays = bleedingDays
        self.variationStdDev = variationStdDev
        self.copy = CycleStatInfoCopy.for(kind: kind)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                CycleStatInfoPersonalReading(
                    kind: kind,
                    previousValue: previousValue,
                    badge: badge
                )

                CycleStatInfoSection(
                    title: "About",
                    paragraph: copy.typical,
                    highlights: copy.typicalHighlights
                )

                CycleStatInfoSection(
                    title: "What can shift it",
                    paragraph: copy.affectIntro,
                    bullets: copy.affectBullets,
                    footnote: copy.affectFootnote
                )

                CycleStatInfoSection(
                    title: "When to check in with a provider",
                    paragraph: copy.doctorIntro,
                    bullets: copy.doctorBullets,
                    footnote: copy.doctorFootnote
                )

                disclaimer
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(DesignColors.journeyBackground.ignoresSafeArea())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var disclaimer: some View {
        Text("cycle.app is not a diagnostic tool and does not provide medical advice. Everything here is for educational context only. For personal concerns, please speak with a licensed healthcare professional.")
            .font(.raleway("Medium", size: 12, relativeTo: .caption))
            .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 8)
    }
}
