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
            Text(title.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary)
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

    /// Serif-italic pull paragraph for highlight lines — kept as the
    /// one editorial moment in an otherwise data-first card so the
    /// "what's typical" range reads with a softer voice than a bare
    /// stat row.
    private func pullQuote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .serif))
            .italic()
            .tracking(-0.1)
            .foregroundStyle(DesignColors.text.opacity(0.78))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 14)
            .padding(.vertical, 2)
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
