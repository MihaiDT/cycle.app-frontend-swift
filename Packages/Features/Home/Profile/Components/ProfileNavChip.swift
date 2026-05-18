import SwiftUI

// MARK: - Profile Nav Chip
//
// Tiny dashed-cycle-gradient circle with an arrow.up.right glyph —
// the same affordance used on StoryHeroCard / BondsCard in the Me
// tab. Replaces plain SF chevrons throughout the Profile screen so
// every "row leads somewhere" reads with the same visual chip.

public struct ProfileNavChip: View {
    public let size: CGFloat

    public init(size: CGFloat = 26) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignColors.calendarPeriodGlyph,
                            DesignColors.calendarFollicularGlyph,
                            DesignColors.calendarFertileGlyph,
                            DesignColors.calendarLutealGlyph,
                            DesignColors.calendarPeriodGlyph,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 4])
                )
            Image(systemName: "arrow.up.right")
                .font(.system(size: size * 0.385, weight: .semibold))
                .foregroundStyle(DesignColors.text)
        }
        .frame(width: size, height: size)
    }
}
