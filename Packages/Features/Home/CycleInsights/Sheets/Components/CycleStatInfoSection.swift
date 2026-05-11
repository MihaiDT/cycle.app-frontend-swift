import SwiftUI

// MARK: - Cycle Stat Info Section
//
// Apple Health–style content card used on each stat info screen.
// Caps eyebrow header on top, then paragraph + optional pull-quote
// highlights + dot bullets + footnote. Wrapped in `widgetCardStyle`
// so each topic reads as its own card on the peach backdrop, just
// like the metric cards on the Body Signals detail screen.

struct CycleStatInfoSection: View {
    let title: String
    let paragraph: String
    var highlights: [String] = []
    var bullets: [String] = []
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.raleway("SemiBold", size: 18, relativeTo: .title3))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignColors.text,
                            DesignColors.textPrincipal,
                            DesignColors.text.opacity(0.85),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .accessibilityAddTraits(.isHeader)

            Text(paragraph)
                .font(.raleway("Regular", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            if !highlights.isEmpty {
                ForEach(highlights, id: \.self) { line in
                    pullQuote(line)
                }
            }

            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bullets, id: \.self) { line in
                        bulletRow(line)
                    }
                }
                .padding(.top, 2)
                .accessibilityElement(children: .contain)
            }

            if let footnote {
                Text(footnote)
                    .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 24)
    }

    /// Pull-quote highlight — Raleway SemiBold replaces the
    /// previous serif italic so the typography stays inside
    /// the app's single Raleway family. The leading inset
    /// keeps it visually distinct from the body paragraph
    /// without using a foreign typeface.
    private func pullQuote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(DesignColors.accentWarm.opacity(0.55))
                .frame(width: 3)
                .accessibilityHidden(true)

            Text(text)
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    /// Dot-marker bullet row — typography carries the scan, no color
    /// on the marker.
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(DesignColors.text.opacity(0.55))
                .frame(width: 4, height: 4)
                .padding(.top, 9)
                .accessibilityHidden(true)

            Text(text)
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
