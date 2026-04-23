import SwiftUI

// MARK: - Cycle History
//
// Editorial retrospective of logged cycles — each entry reads like a
// page from a diary: length & date range, a warm progress bar showing
// where the period and fertile window fell, and three quiet dot rows
// mapping daily check-in values (energy, mood, sleep) onto the cycle
// days that logged them.
//
// Everything is derived from `JourneyData` which CycleInsightsFeature
// already loads via `menstrualLocal.getJourneyData()`. No new
// persistence, no new round trip.


// MARK: - Card

struct CycleHistoryCard: View {
    let timelines: [CycleHistoryTimeline]
    let hiddenKeys: Set<String>
    let onHide: (String) -> Void
    let onUnhide: (String) -> Void
    let onOpenDetail: (String) -> Void
    let onSeeAll: () -> Void

    /// Driving the "Hide cycle" sheet from card-level state instead
    /// of per-entry `@State` sidesteps two SwiftUI quirks:
    ///   1. `.sheet(isPresented:)` attached inside a `ForEach` can
    ///      get cancelled when any sibling identity changes.
    ///   2. Presenting a sheet from several stacks deep inside an
    ///      enclosing `fullScreenCover` sometimes silently no-ops.
    /// A single card-level `item` binding sidesteps both.
    @State private var pendingHide: CycleHistoryTimeline?

    /// Controls whether the hidden-cycles drawer is expanded below
    /// the main list. Collapsed by default so the card stays quiet
    /// for users who haven't hidden anything.
    @State private var showingHidden: Bool = false

    private var visibleTimelines: [CycleHistoryTimeline] {
        timelines
            // History is about *completed* cycles – the current
            // in-progress one is represented elsewhere (phases card,
            // hero). Showing it here makes every fresh install read
            // as "N days · Period: N days" because there's no next
            // cycle yet to derive a real length from.
            .filter { !$0.isCurrent }
            .filter { !hiddenKeys.contains($0.id) }
            .reversed()
            .prefix(3)
            .map { $0 }
    }

    private var hiddenTimelines: [CycleHistoryTimeline] {
        timelines
            .filter { !$0.isCurrent }
            .filter { hiddenKeys.contains($0.id) }
            .reversed()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if visibleTimelines.isEmpty && hiddenTimelines.isEmpty {
                emptyState
            } else if visibleTimelines.isEmpty {
                hiddenOnlyHint
            } else {
                VStack(spacing: 18) {
                    ForEach(Array(visibleTimelines.enumerated()), id: \.element.id) { idx, timeline in
                        CycleHistoryEntry(
                            timeline: timeline,
                            onMenuTap: { pendingHide = timeline }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onOpenDetail(timeline.id) }

                        if idx < visibleTimelines.count - 1 {
                            Rectangle()
                                .fill(DesignColors.text.opacity(DesignColors.dividerOpacity))
                                .frame(height: 1)
                        }
                    }
                }
            }

            if !hiddenTimelines.isEmpty {
                hiddenSection
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 28)
        .sheet(item: $pendingHide) { timeline in
            HideCycleDialog(
                cycleLabel: Self.sheetCycleLabel(for: timeline),
                onConfirm: {
                    onHide(timeline.id)
                    pendingHide = nil
                },
                onCancel: { pendingHide = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private static let sheetDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static func sheetCycleLabel(for timeline: CycleHistoryTimeline) -> String {
        let start = sheetDateFormatter.string(from: timeline.startDate)
        if timeline.isCurrent {
            return "Current cycle · from \(start)"
        }
        let end = sheetDateFormatter.string(from: timeline.endDate)
        return "\(timeline.length) days · \(start) – \(end)"
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            Text("CYCLE\nHISTORY")
                .font(AppTypography.cardTitlePrimary)
                .tracking(AppTypography.cardTitlePrimaryTracking)
                .foregroundStyle(DesignColors.text)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            Button(action: onSeeAll) {
                Text("See all")
                    .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text.opacity(0.85))
                    .padding(.horizontal, AppLayout.screenHorizontal)
                    .padding(.vertical, 8)
                    .background { seeAllGlass }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var seeAllGlass: some View {
        Capsule()
            .fill(DesignColors.text.opacity(0.05))
            .overlay {
                Capsule()
                    .stroke(DesignColors.text.opacity(0.08), lineWidth: 0.6)
            }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your archive is still writing itself.")
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
            Text("Logged cycles will land here. Each one a small page in the diary.")
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var hiddenOnlyHint: some View {
        Text("Every cycle you've logged is hidden right now. Review the list below to bring any back into your averages.")
            .font(.raleway("Medium", size: 13, relativeTo: .footnote))
            .foregroundStyle(DesignColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
            .padding(.vertical, 4)
    }

    // MARK: - Hidden drawer

    /// Collapsed affordance + expandable list of hidden cycles with
    /// a "Bring back" button per entry. Hidden cycles render at 55%
    /// opacity so the eye registers them as quieted, not equal
    /// members of the list — restoring a cycle visually pops it
    /// back to full fidelity on the next layout.
    @ViewBuilder
    private var hiddenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            hiddenToggle

            if showingHidden {
                VStack(spacing: 16) {
                    ForEach(hiddenTimelines) { timeline in
                        hiddenRow(for: timeline)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, visibleTimelines.isEmpty ? 0 : 4)
    }

    @ViewBuilder
    private var hiddenToggle: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                showingHidden.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.8))

                Text(hiddenToggleLabel)
                    .font(.raleway("SemiBold", size: 12, relativeTo: .footnote))
                    .tracking(0.4)
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .rotationEffect(.degrees(showingHidden ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignColors.text.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignColors.text.opacity(0.06), lineWidth: 0.6)
                }
        }
    }

    private var hiddenToggleLabel: String {
        let count = hiddenTimelines.count
        let noun = count == 1 ? "cycle hidden" : "cycles hidden"
        return "\(count) \(noun)"
    }

    @ViewBuilder
    private func hiddenRow(for timeline: CycleHistoryTimeline) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.sheetCycleLabel(for: timeline))
                    .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Button {
                    onUnhide(timeline.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Bring back")
                            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                    }
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(CycleHistoryPressableButtonStyle())
            }

            CycleHistoryBar(timeline: timeline)
                .opacity(0.55)
        }
    }
}
