import ComposableArchitecture
import SwiftUI

// MARK: - CycleInsightsView › Avg Cycle Card + Rhythm Reflection
//
// Two editorial cards on the stats screen — extracted so the main
// CycleInsightsView.swift stays focused on navigation + dispatcher.

extension CycleInsightsView {
    // MARK: - Average Cycle Card
    //
    // Binary render: skeleton while `store.stats` is nil (the fetch
    // in `.onAppear` hasn't come back yet), real card once it lands.
    // No fallback to profile numbers — we'd rather show an honest
    // loading state for ~100ms than flash a number that shifts under
    // the user when the full history arrives. The skeleton mirrors
    // the real card's vertical rhythm so nothing reflows on swap.
    @ViewBuilder
    var avgCycleCard: some View {
        if let stats = store.stats {
            let past = pastCycleEntries
            let lengths = past.map(\.length)
            let avg = Int(stats.cycleLength.average.rounded())
            let minLen = lengths.min() ?? avg
            let maxLen = lengths.max() ?? avg
            let hasRange = !lengths.isEmpty && minLen != maxLen
            avgCycleContent(
                avg: max(avg, 1),
                minLen: minLen,
                maxLen: maxLen,
                count: past.count,
                hasRange: hasRange,
                trendCopy: store.avgTrendCopy
            )
        } else {
            AvgCycleSkeleton()
        }
    }

    // Skeletons live in `CycleInsightsSkeletons.swift` as standalone
    // views (`CycleStatsOverviewSkeleton`, `CycleNormalitySkeleton`,
    // `CycleHistorySkeleton`, `AvgCycleSkeleton`). The dispatcher
    // switches directly on the data-loaded flag and instantiates them.

    @ViewBuilder
    func avgCycleContent(avg: Int, minLen: Int, maxLen: Int, count: Int, hasRange: Bool, trendCopy: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Title on the left, big number on the right — collapses
            // the two-row stack into one row so the card shortens by
            // a full number-block height without sacrificing scale.
            HStack(alignment: .bottom, spacing: 16) {
                Text("YOUR CYCLE\nAVERAGE")
                    .font(AppTypography.cardTitlePrimary)
                    .tracking(AppTypography.cardTitlePrimaryTracking)
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(avg)")
                        .font(.raleway("Bold", size: 48, relativeTo: .largeTitle))
                        .tracking(-1.0)
                        .foregroundStyle(DesignColors.accentWarmText)
                    Text(avg == 1 ? "day" : "days")
                        .font(.raleway("Medium", size: 14, relativeTo: .callout))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }

            HStack(spacing: 0) {
                avgStatSummary(
                    label: "RANGE",
                    value: hasRange ? "\(minLen)–\(maxLen)d" : "\(avg)d"
                )
                Spacer(minLength: 16)
                Rectangle()
                    .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                    .frame(width: 0.5, height: 34)
                Spacer(minLength: 16)
                avgStatSummary(
                    label: "TRACKED",
                    value: count == 0 ? "From profile" : "\(count) \(count == 1 ? "cycle" : "cycles")"
                )
            }

            Text(trendCopy)
                .font(.raleway("Regular", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
    }


    @ViewBuilder
    func avgStatSummary(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                .tracking(0.9)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
            Text(value)
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }



    // MARK: - Rhythm reflection
    //
    // Closing editorial paragraph on Cycle Stats. Phrased in cycle.app
    // voice (present tense, no diagnostic tone, no em dashes). Copy
    // adapts to the actual history — a settling rhythm gets the "your
    // body is finding its rhythm" line with real deltas; a steady
    // rhythm gets a quieter affirmation; an early or restless rhythm
    // gets a patient invitation to keep logging.

    @ViewBuilder
    var rhythmReflection: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(store.rhythmReflectionCopy)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .italic()
                .tracking(-0.3)
                .foregroundStyle(DesignColors.accentWarmText)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 26)
                .padding(.vertical, 56)

            Button {
                isShareReflectionVisible = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignColors.accentWarmText)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .accessibilityLabel("Share reflection")
        }
        .frame(maxWidth: .infinity)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Customize layout plumbing
    //
    // The stats screen renders its cards by iterating over the user's
    // `CycleStatsLayout`. `statsCardView(for:)` is the single switch
    // that maps each enum case to its concrete component, so adding
    // or removing a card is a single-case edit here plus a matching
    // entry in `CycleStatsCard`.

}
