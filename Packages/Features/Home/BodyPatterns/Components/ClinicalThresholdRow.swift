import SwiftUI

/// Single row in the "When to see a doctor" list. Glyph + the
/// threshold sentence + a small caps source attribution chip
/// (NHS / CDC / ACOG / Mayo / NICE).
///
/// Source attribution is mandatory on this surface — every
/// claim has to trace back to public guidance, both for App
/// Store review accountability and for users who want to verify.
struct ClinicalThresholdRow: View {
    let glyph: String
    let text: String
    let source: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: glyph)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DesignColors.accentWarm)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(text)
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(source.uppercased())
                    .font(.raleway("Bold", size: 9, relativeTo: .caption2))
                    .tracking(1.0)
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
