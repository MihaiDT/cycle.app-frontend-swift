import SwiftUI

/// High-contrast urgent-care callout for the "Get help now"
/// section of "When to see a doctor". Visually distinct from
/// routine consultation rows (filled card, warm-red palette,
/// triangle warning glyph) so the user can tell at a glance
/// which level of urgency a row carries.
///
/// Tone: declarative, not panicky. Lists conditions + footer
/// with the action ("Call 911 / 999 / 112 or go to A&E").
struct EmergencyCallout: View {
    let title: String
    let items: [String]
    let footer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.raleway("Bold", size: 16, relativeTo: .headline))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(item)
                            .font(.raleway("Medium", size: 14, relativeTo: .body))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(footer)
                .font(.raleway("SemiBold", size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.30, blue: 0.30),
                            Color(red: 0.62, green: 0.22, blue: 0.30),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        }
    }
}
