import SwiftUI

// MARK: - Cycle Stat Info Section
//
// Numbered editorial section used inside each stat info screen.
// Handles the sign-posted header ("01  What's typical"), body
// paragraph, optional highlights rendered as serif-italic pull quotes,
// dot-marker bullets, and a trailing footnote. Typography-led: no
// icons, no colored chrome.

struct CycleStatInfoSection: View {
    let number: Int
    let title: String
    let paragraph: String
    var highlights: [String] = []
    var bullets: [String] = []
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading

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
                    .padding(.top, 6)
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(String(format: "%02d", number))
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Serif-italic pull paragraph for highlight lines — matches the
    /// app's only other editorial italic moment (rhythm reflection on
    /// the stats screen).
    private func pullQuote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .regular, design: .serif))
            .italic()
            .tracking(-0.1)
            .foregroundStyle(DesignColors.text.opacity(0.78))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 18)
            .padding(.vertical, 4)
    }

    /// Dot-marker bullet row — typography carries the scan, no color
    /// on the marker.
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(DesignColors.text.opacity(0.55))
                .frame(width: 4, height: 4)
                .padding(.top, 9)
                .accessibilityHidden(true)

            Text(text)
                .font(.raleway("Regular", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
