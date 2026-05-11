import SwiftUI

/// Compact footer listing the public sources used to draft the
/// surface above. Required on safety-sensitive screens so users
/// (and Apple reviewers) can trace any claim back to its origin.
struct SourceCitationFooter: View {
    let intro: String
    let sources: [String]

    init(
        intro: String = "Based on public guidance from",
        sources: [String]
    ) {
        self.intro = intro
        self.sources = sources
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(intro)
                .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                .foregroundStyle(DesignColors.textSecondary)
            Text(sources.joined(separator: " · "))
                .font(.raleway("Bold", size: 11, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
