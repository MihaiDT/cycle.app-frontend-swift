import SwiftUI

// MARK: - Cycle Live Widget
//
// Journey-page hero widget: an editorial "what this week means" card
// keyed off the active phase and (when available) the category of the
// Your moment tile on Rhythm. Rhythm shows the action ("do this").
// Journey shows the context ("here's why it fits this week"). Same
// underlying category, two layers of the same story.
//
// Purely presentational — the view takes content already derived by
// `CycleLiveEngine`.

public struct CycleLiveWidget: View {
    public let content: CycleLiveContent
    public let daysUntilNextPeriod: Int?
    public let onTap: (() -> Void)?

    public init(
        content: CycleLiveContent,
        daysUntilNextPeriod: Int? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.content = content
        self.daysUntilNextPeriod = daysUntilNextPeriod
        self.onTap = onTap
    }

    public var body: some View {
        cardBody
            .widgetCardStyle()
    }

    @ViewBuilder
    private var cardBody: some View {
        if let onTap {
            Button(action: onTap) { innerContent }
                .buttonStyle(.plain)
        } else {
            innerContent
        }
    }

    @ViewBuilder
    private var innerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metaLabel.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.bottom, 10)

            Text(content.title)
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 6)

            Text(content.body)
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if onTap != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.5))
                    .padding(16)
            }
        }
    }

    // MARK: Derived labels

    private var metaLabel: String {
        guard content.phase != .late else { return "Cycle Live" }
        if let day = content.cycleDay {
            return "\(content.phase.displayName) · Day \(day)"
        }
        return content.phase.displayName
    }

    private var footerLabel: String? {
        guard let days = daysUntilNextPeriod, days > 0 else { return nil }
        if days == 1 { return "Period expected tomorrow" }
        return "Period expected in ~\(days) days"
    }
}
