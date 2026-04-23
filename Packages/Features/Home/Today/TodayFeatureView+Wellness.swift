import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Today › Wellness Section (extracted from TodayFeatureView)

extension TodayView {
    // MARK: - Wellness Section (W2)

    /// Home's wellness card + optional Aria voice line. Three states:
    /// - Resolved HBI → tappable widget with trend + optional Aria line
    /// - Actively loading (no dashboard yet) → skeleton
    /// - No check-in today → empty-state widget that nudges toward the
    ///   daily check-in instead of a permanent shimmer.
    /// Widget-level carousel pairing Rhythm with Journey (and any future
    /// widget pages). Section header's title and trailing dots track the
    /// visible page — no full-page paging, only the widget area swipes.
    private var widgetSectionPageCount: Int { 2 }

    private var widgetSectionTitle: String {
        switch rhythmPage {
        case 1:  return "Journey"
        default: return "Rhythm"
        }
    }

    @ViewBuilder
    var wellnessSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom section header with a staggered letter reveal so the
            // title animates when the user pages between widgets.
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                StaggeredTitle(text: widgetSectionTitle)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 10)

            HomeWidgetCarousel(
                currentIndex: $rhythmPage,
                pageCount: widgetSectionPageCount,
                horizontalPadding: AppLayout.screenHorizontal
            ) { index in
                switch index {
                case 0: rhythmPageContent
                case 1: journeyPageContent
                default: EmptyView()
                }
            }

            // Dots centered below the carousel — more visible than a
            // trailing slot on the section header, and give users a clear
            // handle to tap between pages.
            HStack {
                Spacer()
                HomeWidgetCarouselDots(
                    pageCount: widgetSectionPageCount,
                    currentIndex: $rhythmPage
                )
                Spacer()
            }
            .padding(.top, 14)
        }
    }

    /// Rhythm page — existing wellness widget + two ritual tiles.
    /// Trailing Spacer anchors content to the top so the Rhythm tiles
    /// don't stretch when the carousel sizes to the taller Journey page.
    @ViewBuilder
    private var rhythmPageContent: some View {
        VStack(spacing: 0) {
            wellnessBody
            Spacer(minLength: 0)
        }
    }

    /// Journey page — 3 destination boxes: Journey (recap stories),
    /// Cycle Stats (averages & trends), Body Patterns (symptoms & signals).
    /// Kept structurally symmetric with the Rhythm page (hero + tile row)
    /// so the carousel height stays constant across pages.
    @ViewBuilder
    private var journeyPageContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                JourneyDestinationTile(
                    kind: .stats,
                    stat: cycleStatsPreview,
                    onTap: { store.send(.delegate(.openCycleStats)) }
                )

                JourneyDestinationTile(
                    kind: .body,
                    stat: bodyPatternsPreview,
                    onTap: { store.send(.delegate(.openBodyPatterns)) }
                )
            }

            JourneyDestinationCard(
                subtitle: journeyCardSubtitle,
                isNew: store.recapBannerMonth != nil,
                onTap: { store.send(.delegate(.openCycleJourney)) }
            )

            // Anchor content to the top so the carousel doesn't stretch
            // child tiles when a sibling page happens to be shorter.
            Spacer(minLength: 0)
        }
    }

    private var journeyCardSubtitle: String {
        if let month = store.recapBannerMonth {
            return "Your \(month) recap is ready."
        }
        return "Every cycle, a chapter of your story."
    }

    private var cycleStatsPreview: String {
        guard let avg = store.menstrualStatus?.profile.avgCycleLength, avg > 0 else {
            return "—"
        }
        return "~\(avg)d"
    }

    private var bodyPatternsPreview: String {
        guard let phase = store.wellnessPhase else { return "—" }
        return phase.rawValue.capitalized
    }

    /// Wellness section body. Layout mirrors Apple Home widgets / Cal AI:
    /// one big hero widget (ring + score) on top, a grid of smaller ritual
    /// tiles below. The widget only appears after the daily check-in lands
    /// — before then, the tiles are the primary surface so the user has
    /// two obvious, equal-weight things to tap.
    @ViewBuilder
    private var wellnessBody: some View {
        VStack(spacing: 12) {
            if store.hasCompletedCheckIn, let adjusted = store.wellnessAdjusted {
                WellnessWidget(
                    adjusted: adjusted,
                    trendVsBaseline: store.wellnessTrendVsBaseline,
                    phase: store.wellnessPhase,
                    cycleDay: store.wellnessCycleDay,
                    sourceLabel: store.wellnessSourceLabel,
                    onDetailTap: { store.send(.wellnessTapped) }
                )
            } else if store.isLoadingDashboard, store.dashboard == nil {
                WellnessWidgetSkeleton()
            } else {
                wellnessAwaitingCard
            }

            ritualTilesRow

            if store.shouldShowAriaVoice {
                AriaVoiceLine(phase: store.wellnessPhase)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Pre-check-in placeholder that sits in the widget slot until the
    /// score is ready. Mirrors the widget's shape and meta row so the
    /// section layout stays stable and the tiles don't drift upward.
    @ViewBuilder
    private var wellnessAwaitingCard: some View {
        let meta: String? = {
            guard let phase = store.wellnessPhase, phase != .late else { return nil }
            if let day = store.wellnessCycleDay {
                return "\(phase.displayName.uppercased()) · DAY \(day)"
            }
            return phase.displayName.uppercased()
        }()

        VStack(alignment: .leading, spacing: 0) {
            if let meta {
                Text(meta)
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(0.6)
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.bottom, 12)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your rhythm is waiting")
                        .font(.raleway("Bold", size: 22, relativeTo: .title3))
                        .tracking(-0.3)
                        .foregroundStyle(DesignColors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Start with today's rituals below to unlock your score.")
                        .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 6, dash: [3, 5])
                        )
                        .foregroundStyle(DesignColors.text.opacity(0.12))
                        .frame(width: 84, height: 84)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DesignColors.text.opacity(0.25))
                }
            }
        }
        .padding(18)
        .widgetCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rhythm is waiting. Start with today's rituals to unlock your score.")
    }

    /// Two Cal-AI-style tiles side by side: check-in + moment. Always visible
    /// so the day's rituals have a stable home — the widget above them comes
    /// and goes based on whether the score is ready, but the call-to-action
    /// surface is constant.
    @ViewBuilder
    private var ritualTilesRow: some View {
        let checkInDone = store.hasCompletedCheckIn
        let momentDone: Bool = {
            if case .completed = store.dailyChallengeState.challengeState { return true }
            return false
        }()
        let challenge = store.dailyChallengeState.challenge
        let momentSubtitle = challenge?.challengeTitle ?? "Today's gentle moment"
        let momentIcon = challenge?.tileIconName ?? "sparkles"

        HStack(spacing: 12) {
            WellnessRitualTile(
                title: "Check-in",
                subtitle: "How do you feel?",
                iconName: "heart.fill",
                isDone: checkInDone,
                onTap: { store.send(.checkInTapped) }
            )

            WellnessRitualTile(
                title: "Your moment",
                subtitle: momentSubtitle,
                iconName: momentIcon,
                isDone: momentDone,
                onTap: { store.send(.dailyChallenge(.doItTapped)) }
            )
        }
    }

}
