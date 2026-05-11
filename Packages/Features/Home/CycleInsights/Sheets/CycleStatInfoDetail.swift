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
        ZStack {
            // Same warm peach surface as Body Patterns / Cycle
            // Stats / About — keeps the info screens reading
            // as part of the same surface family rather than a
            // settings-style modal.
            AppleHealthBackground()
                .ignoresSafeArea()

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

                    MedicalDeviceDisclaimer()
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // Disclaimer is now provided by the shared
    // `MedicalDeviceDisclaimer` component so the wording +
    // typography stay identical across every educational
    // surface (Body Patterns about, When to see a doctor,
    // stat info screens).
}
