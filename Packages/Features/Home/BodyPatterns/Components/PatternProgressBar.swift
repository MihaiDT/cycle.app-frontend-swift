import SwiftUI

// MARK: - Pattern Progress Bar
//
// Glowing-orb progress visualization. One orb per cycle in the
// lookback window — filled orbs use a soft radial gradient in the
// phase ink with a luminous halo around them; empty orbs are thin
// petal-like outlines. Below sits an italic numeric headline.
// Reads as feminine, premium, artistic — closer to the
// Pillow / Calm aesthetic than to a Wallet rewards bar.

struct PatternProgressBar: View {

    let total: Int
    let filled: Int
    let fillColor: Color
    let trackColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Caps eyebrow leads so the user reads the scope
            // ("CYCLES") before the numeric — mirrors the rest
            // of the surface's editorial register and pulls
            // the centred-then-bottom-eyebrow stack into a
            // single top-down hierarchy.
            Text("CYCLES")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(2.0)
                .foregroundStyle(DesignColors.text.opacity(0.55))

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(filled)")
                    .font(.raleway("Bold", size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                    .monospacedDigit()
                    .tracking(-1.8)

                Text("of \(total)")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .caption))
                    .foregroundStyle(DesignColors.text.opacity(0.55))
                    .monospacedDigit()
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("4 of 5") {
    PatternProgressBar(
        total: 5,
        filled: 4,
        fillColor: Color(red: 0.79, green: 0.25, blue: 0.38),
        trackColor: Color(red: 0.79, green: 0.25, blue: 0.38).opacity(0.18)
    )
    .padding(40)
    .background(Color.white)
}

#Preview("2 of 4") {
    PatternProgressBar(
        total: 4,
        filled: 2,
        fillColor: Color(red: 0.62, green: 0.34, blue: 0.42),
        trackColor: Color(red: 0.62, green: 0.34, blue: 0.42).opacity(0.18)
    )
    .padding(40)
    .background(Color.white)
}
#endif
