import ComposableArchitecture
import SwiftUI

extension CalendarFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var menstrualStatus: MenstrualStatusResponse?
        public var displayedMonth: Date
        public var selectedDate: Date
        public var loggedDays: [String: DayLog] = [:]
        public var symptomSearchText: String = ""
        public var isShowingSymptomSheet: Bool = false
        public var isSavingSymptoms: Bool = false
        public var symptomsSaved: Bool = false
        /// When the sheet is opened from a specific log entry —
        /// e.g. tapping a chip in Body Patterns' recent-logs
        /// strip — this carries the raw `SymptomType` so the
        /// sheet can switch its category tab to match the
        /// symptom (otherwise the user lands on "For you" and
        /// can't see the symptom they came from). The view
        /// consumes the value once and dispatches
        /// `.pendingFocusedSymptomCleared` to reset.
        public var pendingFocusedSymptomRaw: String?
        public var showAriaPrompt: Bool = false
        public var ariaPromptMessage: String = ""
        public var isLoadingCalendar: Bool = false
        /// True after pre-loading calendar data at app start
        public var hasPreloaded: Bool = false
        public var calendarEntries: [MenstrualCalendarEntry] = []

        // Effective cycle params (may be edited by user)
        public var cycleStartDate: Date
        public var cycleLength: Int
        public var bleedingDays: Int

        // Display preferences mirrored from MenstrualCalendarResponse.
        // Default true so the calendar renders fully until a load resolves.
        public var showOvulation: Bool = true
        public var showFertileWindow: Bool = true

        /// Unified cycle-derived calendar data — single source of truth.
        /// `periodDays` / `predictedPeriodDays` / `periodFlowIntensity` /
        /// `fertileDays` / `ovulationDays` are computed passthroughs into this.
        public var snapshot: CycleSnapshot = .empty

        // User-marked period days (keys: "yyyy-MM-dd") — confirmed + predicted from server
        public var periodDays: Set<String> {
            get { snapshot.periodDays }
            set { snapshot.periodDays = newValue }
        }
        // Server-predicted period days (subset of periodDays) — for dashed/lighter styling
        public var predictedPeriodDays: Set<String> {
            get { snapshot.predictedDays }
            set { snapshot.predictedDays = newValue }
        }
        // Flow intensity per period day (keys: "yyyy-MM-dd")
        public var periodFlowIntensity: [String: FlowIntensity] {
            get { snapshot.flowIntensity }
            set { snapshot.flowIntensity = newValue }
        }
        // Fertile days with their level (keys: "yyyy-MM-dd")
        public var fertileDays: [String: FertilityLevel] {
            get { snapshot.fertileDays }
            set { snapshot.fertileDays = newValue }
        }
        // Ovulation days (keys: "yyyy-MM-dd")
        public var ovulationDays: Set<String> {
            get { snapshot.ovulationDays }
            set { snapshot.ovulationDays = newValue }
        }

        // Inline edit period mode
        public var isEditingPeriod: Bool = false
        public var editPeriodDays: Set<String> = []
        public var editOriginalPeriodDays: Set<String> = []
        public var editFlowIntensity: [String: FlowIntensity] = [:]
        public var isUpdatingPredictions: Bool = false
        public var predictionsDone: Bool = false
        /// Bumped after calendar reload to trigger refresh animation
        public var calendarRefreshTick: Int = 0

        public var hasEditPeriodChanges: Bool {
            editPeriodDays != editOriginalPeriodDays
        }

        public struct DayLog: Equatable, Sendable {
            public var symptoms: [String] = []
            public var notes: String = ""
            /// Per-symptom severity 1–5. Symptom raw value is the
            /// key. Defaults to 3 (moderate) on first selection;
            /// the user adjusts via the long-press menu on the
            /// symptom card. Persisted to `SymptomRecord.severity`
            /// at save time so `PatternDetector` can weight
            /// recurrence by intensity later.
            public var severities: [String: Int] = [:]
        }

        public init(
            menstrualStatus: MenstrualStatusResponse? = nil,
            periodDays: Set<String> = [],
            predictedPeriodDays: Set<String> = [],
            fertileDays: [String: FertilityLevel] = [:],
            ovulationDays: Set<String> = []
        ) {
            self.menstrualStatus = menstrualStatus
            let today = Calendar.current.startOfDay(for: Date())
            self.selectedDate = today
            var comps = Calendar.current.dateComponents([.year, .month], from: today)
            comps.day = 1
            self.displayedMonth = Calendar.current.date(from: comps) ?? today

            let hasCycleData = menstrualStatus?.hasCycleData ?? false
            let localCal = Calendar.current
            if hasCycleData, let serverStart = menstrualStatus?.currentCycle.startDate {
                let startDate = CalendarFeature.localDate(from: serverStart)
                self.cycleStartDate = localCal.startOfDay(for: startDate)
            } else {
                self.cycleStartDate = localCal.date(byAdding: .year, value: -100, to: today) ?? today
            }
            self.cycleLength = menstrualStatus?.profile.avgCycleLength ?? 28
            self.bleedingDays = menstrualStatus?.currentCycle.bleedingDays ?? 5

            // Pre-populate with already-loaded data for instant display.
            // Writing into the unified snapshot (computed accessors proxy into it).
            self.snapshot = CycleSnapshot(
                periodDays: periodDays,
                predictedDays: predictedPeriodDays,
                fertileDays: fertileDays,
                ovulationDays: ovulationDays
            )
        }
    }
}
