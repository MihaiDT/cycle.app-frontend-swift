import SwiftUI

/// Live summary of the symptoms the user has toggled on for the
/// current day. Floats above the search/settings bar at the
/// bottom of `CalendarSymptomSheet`, so the user can:
///   * see at a glance what they've already picked without
///     scrolling the grid
///   * un-pick directly from here via the pill's trailing X
///
/// Wraps `SymptomSummaryPill` (already styled with the warm
/// accentSecondary capsule) inside a horizontal scroller. The
/// row is meant to span its parent edge-to-edge — pills
/// carry their own leading inset on the inner HStack so they
/// can scroll past the editorial column. Default ScrollView
/// clip is kept on so the bleed never paints outside the
/// sheet, which previously caused the pills to "stay behind"
/// during the dismiss slide-out.
struct SymptomSelectedStrip: View {
    let symptoms: [SymptomType]
    let onRemove: (SymptomType) -> Void

    /// Leading inset that the inner HStack carries so the
    /// first pill starts inside the editorial column, then
    /// can scroll past it.
    private static let contentInset: CGFloat = 24

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(symptoms, id: \.rawValue) { symptom in
                    SymptomSummaryPill(
                        symptom: symptom,
                        onRemove: { onRemove(symptom) }
                    )
                }
            }
            .padding(.horizontal, Self.contentInset)
        }
    }
}
