import SwiftUI

/// Vertical 3-column grid of `SymptomIconCard`. Decoupled from
/// `SymptomCategory` so callers can pass an arbitrary list —
/// e.g. a search-filtered subset, the For-you tab's
/// phase-tuned set, or a future cross-category result list.
///
/// Caller owns selection state through the `severities`
/// dictionary (raw value → 1/3/5) and dispatches both the tap
/// (toggle) and the long-press (severity menu) callbacks.
struct SymptomCategoryPage: View {
    let symptoms: [SymptomType]
    let tintColor: Color
    let severities: [String: Int]
    let onToggle: (SymptomType) -> Void
    let onLongPress: (SymptomType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(symptoms, id: \.rawValue) { symptom in
                    SymptomIconCard(
                        symptom: symptom,
                        severity: severities[symptom.rawValue] ?? 0,
                        tintColor: tintColor,
                        onTap: { onToggle(symptom) },
                        onLongPress: { onLongPress(symptom) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            // Bottom inset reserves room for the floating
            // overlay (selection placeholder + selected strip
            // + bottom bar). Sized to clear all three even
            // when the strip is open, so the last grid row
            // never tucks under the search bar — and now
            // padded enough that the last row doesn't half-
            // clip under the bottom mask either (the audit
            // showed two cards bleeding under the fade in
            // Mood — this brings them above it).
            .padding(.bottom, 200)
        }
        // Soft bottom fade — signals "more below" on
        // categories with longer lists (e.g. Physical, Mood)
        // without competing with content. On short categories
        // the gradient lands on padding only, so it stays
        // invisible.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.005),
                    .init(color: .black, location: 0.94),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
