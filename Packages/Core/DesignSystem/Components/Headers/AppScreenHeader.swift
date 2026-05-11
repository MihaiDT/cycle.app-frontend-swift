import SwiftUI

/// Editorial screen / sheet header used across the app.
///
/// One pattern, one place — so every primary surface reads with
/// the same typographic mood: caps + tracked eyebrow, then a
/// big gradient title that reflows on a second line. Drop this
/// in immediately under any toolbar / action row and the header
/// will feel native to the rest of the app.
///
/// Both BodyPatterns, CycleInsights, and the symptom logging
/// sheet feed off this so a copy change in any of them stays
/// visually identical to the others.
///
/// - Parameter eyebrow: Optional caps eyebrow — pass `nil` (or
///   an empty string) to skip the row entirely. Useful when
///   the surface owns its date / context cue elsewhere
///   (e.g. a day pill picker right under the header).
/// - Parameter title: The display title. Allowed to wrap to two
///   lines; sized via `largeTitle` Dynamic Type metrics so the
///   layout breathes on Accessibility sizes.
public struct AppScreenHeader: View {
    public let eyebrow: String?
    public let title: String

    public init(eyebrow: String? = nil, title: String) {
        self.eyebrow = eyebrow
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.raleway("Bold", size: 11, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(DesignColors.textSecondary)
                    // Native iOS text content transition — flips
                    // glyphs in place when the eyebrow value
                    // changes (e.g. TODAY → YESTERDAY → FRIDAY
                    // as the user picks a different log day).
                    // `numericText` ships the cubic glyph
                    // morphing the user asked for.
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.32), value: eyebrow)
                    .accessibilityLabel(eyebrow)
            }

            Text(title)
                .font(.raleway("Bold", size: 32, relativeTo: .largeTitle))
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
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
}
