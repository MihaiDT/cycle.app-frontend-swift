import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Today Feature › State

extension TodayFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var dashboard: HBIDashboardResponse?
        public var isLoadingDashboard: Bool = false
        public var dashboardError: String?

        public var menstrualStatus: MenstrualStatusResponse?
        public var isLoadingMenstrual: Bool = false

        /// Unified cycle-derived calendar data — single source of truth for
        /// `periodDays` / `predictedDays` / `fertileDays` / `ovulationDays` /
        /// `flowIntensity`. Propagated to `calendarState.snapshot` on every
        /// server load so Calendar/EditPeriod read from the same source.
        public var snapshot: CycleSnapshot = .empty

        @Presents var checkIn: DailyCheckInFeature.State?
        @Presents var moodArc: MoodArcFeature.State?
        /// Wellness detail sheet — hydrated from today's HBI on tap so the
        /// sheet opens with the same numbers the widget just rendered.
        @Presents var wellnessDetail: WellnessDetailFeature.State?
        /// Always-present calendar state — pre-loaded so opening is instant
        public var calendarState: CalendarFeature.State = CalendarFeature.State()
        /// Controls calendar visibility (fullScreenCover)
        public var isCalendarVisible: Bool = false

        /// True while reloading cycle data after an edit (shows loading on hero)
        public var isRefreshingCycleData: Bool = false
        public var hasCompletedCalendarLoad: Bool = false

        /// Sync status for the toast on Home
        public enum SyncStatus: Equatable, Sendable {
            case idle
            case syncing
            case synced
        }
        public var syncStatus: SyncStatus = .idle

        /// Single source of truth for all cycle data — derived from server responses.
        /// Shows immediately with menstrualStatus; calendar data enriches when ready.
        public var cycle: CycleContext? {
            guard let status = menstrualStatus else { return nil }
            return CycleContext.from(
                status: status,
                periodDays: snapshot.periodDays,
                predictedDays: snapshot.predictedDays,
                fertileDays: snapshot.fertileDays,
                ovulationDays: snapshot.ovulationDays
            )
        }

        /// Cached stats from last CycleInsights visit (for entry card sparkline)
        public var cachedCycleStats: CycleStatsDetailedResponse?

        // Late period confirm sheet
        public var isShowingLateConfirmSheet: Bool = false

        public var hasAppeared: Bool = false

        // AI Wellness message
        public var wellnessMessage: String?
        public var isLoadingWellnessMessage: Bool = false
        public var hasTriggeredScoreAnimation: Bool = false
        public var scoreAnimationProgress: Double = 0

        public var hasCompletedCheckIn: Bool {
            dashboard?.latestReport != nil
        }

        public var todayScore: Int {
            dashboard?.today?.hbiAdjusted ?? 0
        }

        public var trendDirection: String? {
            dashboard?.today?.trendDirection
        }

        // MARK: — Wellness hero (W2)
        //
        // Mirrors of the latest `HBIScore` used to feed `WellnessWidget` on
        // Home and seed the `WellnessDetailFeature` when the sheet opens.
        // All values derive from `dashboard?.today` — never from math here.

        /// 0-100 adjusted score from W1.
        public var wellnessAdjusted: Double? {
            guard let today = dashboard?.today else { return nil }
            return Double(today.hbiAdjusted)
        }

        /// Signed delta vs the user's own phase baseline. `nil` when baseline
        /// confidence is insufficient — widget renders the "building" copy.
        public var wellnessTrendVsBaseline: Double? {
            dashboard?.today?.trendVsBaseline
        }

        /// Resolved `CyclePhase` for the widget's header. Late is downgraded
        /// to `.luteal` for layout (widget hides meta on `.late`).
        public var wellnessPhase: CyclePhase? {
            guard let raw = dashboard?.today?.cyclePhase else {
                return cycle?.currentPhase
            }
            return CyclePhase(rawValue: raw) ?? cycle?.currentPhase
        }

        /// Cycle day paired with phase label ("Luteal · Day 22").
        public var wellnessCycleDay: Int? {
            dashboard?.today?.cycleDay ?? cycle?.cycleDay
        }

        /// "Based on" footer copy. Uses whichever signals hydrated today's
        /// score; empty check-in state falls back to a gentle onboarding line.
        public var wellnessSourceLabel: String {
            guard let today = dashboard?.today else {
                return "Complete your first check-in"
            }
            var pieces: [String] = []
            if today.hasSelfReport { pieces.append("Today's check-in") }
            if today.hasHealthkitData { pieces.append("Health data") }
            if pieces.isEmpty { pieces.append("Building your picture") }
            return pieces.joined(separator: " · ")
        }

        /// True when the Aria voice line should render under the widget.
        /// Only fires when the trend is meaningfully positive so we don't
        /// nag on routine fluctuations.
        public var shouldShowAriaVoice: Bool {
            guard let trend = wellnessTrendVsBaseline else { return false }
            return trend > 3
        }

        // MARK: — Cycle Live (Journey page)
        //
        // Editorial snippet for the Journey page Cycle Live widget.
        // Mirrors the Your moment category from Rhythm so both pages
        // reference the same underlying choice (action vs context).

        public var cycleLiveContent: CycleLiveContent? {
            guard let phase = wellnessPhase else { return nil }
            let category = dailyChallengeState.challenge?.challengeCategory
            return CycleLiveEngine.content(
                phase: phase,
                cycleDay: wellnessCycleDay,
                momentCategory: category
            )
        }

        public var cycleLiveDaysUntilPeriod: Int? {
            guard let days = cycle?.daysUntilPeriod(from: Date()) else {
                return nil
            }
            return days > 0 ? days : nil
        }

        // Your Day — Lens previews
        public var yourDayState: YourDayFeature.State = YourDayFeature.State()

        // Daily Glow challenge
        public var dailyChallengeState: DailyChallengeFeature.State = DailyChallengeFeature.State()

        // Notifications
        public var recapBannerMonth: String?
        public var isRecapSheetVisible: Bool = false
        public var isNotificationsPanelVisible: Bool = false

        // Echo from last cycle (same cycle-day, one cycle ago).
        // Surfaces on Home's Journey page and drives the Day Detail sheet.
        public var echoPayload: DayDetailPayload?
        public var dayDetailPayload: DayDetailPayload?

        public init() {}
    }
}
