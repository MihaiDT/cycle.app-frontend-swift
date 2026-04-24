import SwiftUI

// MARK: - Cycle Stat Info Detail
//
// Editorial explainer opened from the Normality card's info buttons.
// This view is a thin coordinator — it composes the header
// illustration, the personal reading row, and three numbered content
// sections, all of which live in their own files under `Components/`.
// Copy lives in `CycleStatInfoCopy.swift`.

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
            VStack(alignment: .leading, spacing: 0) {
                CycleStatInfoHeaderImage(kind: kind)

                VStack(alignment: .leading, spacing: 40) {
                    CycleStatInfoPersonalReading(
                        kind: kind,
                        previousValue: previousValue,
                        badge: badge
                    )

                    CycleStatInfoSection(
                        number: 1,
                        title: "What's typical",
                        paragraph: copy.typical,
                        highlights: copy.typicalHighlights
                    )

                    CycleStatInfoSection(
                        number: 2,
                        title: "What can shift it",
                        paragraph: copy.affectIntro,
                        bullets: copy.affectBullets,
                        footnote: copy.affectFootnote
                    )

                    CycleStatInfoSection(
                        number: 3,
                        title: "When to check in with a provider",
                        paragraph: copy.doctorIntro,
                        bullets: copy.doctorBullets,
                        footnote: copy.doctorFootnote
                    )

                    disclaimer
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 56)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Same surface as the Cycle Stats parent screen so the info
        // reads as a continuation, not a separate modal.
        .background { JourneyAnimatedBackground(animated: false) }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(DesignColors.text.opacity(0.10))
                .frame(height: 0.5)
                .accessibilityHidden(true)

            Text("cycle.app is not a diagnostic tool and does not provide medical advice. Everything you read here is for educational context only. For personal concerns, please speak with a licensed healthcare professional.")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}
