import ComposableArchitecture
import Foundation

// MARK: - Body Patterns Feature
//
// TCA reducer for the Body Patterns destination screen pushed from
// Today's symptom-pattern card.
//
// Phase 1 (this commit) ships with mocked patterns so the UI lands
// immediately. Phase 2 plugs in `PatternDetector.detect(...)` over
// the user's `SymptomRecord` history. Phase 3 routes the editorial
// body line through OpenAI for personalised hormonal copy.
//
// State design:
//   - `active` / `emerging` are split arrays so the View doesn't
//     re-derive on every render.
//   - `isLoading` toggles the skeleton silhouette during the (eventual)
//     SwiftData fetch + detector run.
//   - `pendingDismiss` is the standard delegate pattern used elsewhere
//     in the app (CycleInsights, CycleJourney) to bubble close events
//     up to HomeFeature without coupling navigation here.

@Reducer
public struct BodyPatternsFeature: Sendable {

    @Dependency(\.menstrualLocal) var menstrualLocal

    @ObservableState
    public struct State: Equatable, Sendable {
        public var active: [DetectedPattern]
        public var emerging: [DetectedPattern]
        public var recentLogs: [RecentSymptomEntry]
        /// Why-Engine synthesis paragraph rendered as the closing
        /// `BodyPatternsReadingCard` at the bottom of the feed.
        /// Recomputed on every `patternsLoaded`. Nil when there's
        /// nothing to say (no active, no emerging) — host hides
        /// the card.
        public var overviewReading: PatternReading?
        public var isLoading: Bool
        public var hasAppeared: Bool
        /// Currently pushed informational screen, if any. Drives
        /// `.navigationDestination(item:)` on the View so the same
        /// child screens can be triggered from the header info
        /// button or the footer rows.
        public var presentedDestination: Destination?

        /// Informational children pushed on top of the patterns
        /// list. Three screens, three reasons:
        ///   * `.about` — one-tap context behind the header `i`
        ///     button. Privacy + brief feature explainer.
        ///   * `.howPatternsWork` — algorithm explainer (phases,
        ///     thresholds, what patterns are not).
        ///   * `.whenToSeeDoctor` — clinical safety guidance
        ///     sourced from ACOG / NHS / CDC / Mayo. Required for
        ///     App Store review (Guideline 1.4.1: remind users to
        ///     consult a clinician before medical decisions).
        public enum Destination: Hashable, Sendable {
            case about
            case howPatternsWork
            case whenToSeeDoctor
            /// Push destination from a pattern carousel tap.
            /// Carries the full `DetectedPattern` so the
            /// detail screen has everything it needs without
            /// a second store lookup.
            case patternDetail(DetectedPattern)
        }

        public init(
            active: [DetectedPattern] = [],
            emerging: [DetectedPattern] = [],
            recentLogs: [RecentSymptomEntry] = [],
            overviewReading: PatternReading? = nil,
            isLoading: Bool = false,
            hasAppeared: Bool = false,
            presentedDestination: Destination? = nil
        ) {
            self.active = active
            self.emerging = emerging
            self.recentLogs = recentLogs
            self.overviewReading = overviewReading
            self.isLoading = isLoading
            self.hasAppeared = hasAppeared
            self.presentedDestination = presentedDestination
        }

        /// Whether to render the patterns list or the empty state.
        /// We treat "no active AND no emerging" as empty even when
        /// the detector has run — the user simply has nothing yet.
        public var isEmpty: Bool {
            active.isEmpty && emerging.isEmpty
        }
    }

    public enum Action: Sendable {
        case onAppear
        case dismissTapped
        case logSymptomsTapped
        case recentLogTapped(Date, symptomRaw: String)
        case patternTapped(DetectedPattern)
        case howItWorksTapped
        case whenToSeeDoctorTapped
        case infoTapped
        case destinationDismissed

        // Detector lifecycle (Phase 2 hook — wired up but currently
        // returns mock data immediately so the UI renders end-to-end
        // before the real algorithm exists).
        case loadPatterns
        case patternsLoaded(active: [DetectedPattern], emerging: [DetectedPattern])
        case recentLogsLoaded([RecentSymptomEntry])

        case delegate(Delegate)
        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case dismiss
            /// Bubble Log Symptoms up so the parent (Home) can route
            /// the user back to Today and surface the calendar
            /// symptom sheet — the same destination as the existing
            /// pill on `symptomPatternSection`.
            case logSymptoms
            /// Same destination as `.logSymptoms` but pre-selecting a
            /// specific calendar day **and** the symptom's category
            /// tab. Fires when the user taps a chip in the recent-
            /// logs strip — "show me this entry where it was
            /// logged, on the right tab".
            case logSymptomsForDate(Date, symptomRaw: String)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                return .send(.loadPatterns)

            case .loadPatterns:
                // Phase 2: run `PatternDetector` over the user's
                // 12-month symptom + cycle history. The client
                // method already hops to a detached task internally;
                // we just await + map raw signals → `DetectedPattern`
                // here on the main actor.
                //
                // No mock fallback — empty result means the user
                // genuinely has no recurring patterns yet, and the
                // empty-state widget handles that. Errors log but
                // also resolve to empty so the screen never crashes.
                state.isLoading = true
                return .run { [menstrualLocal] send in
                    // Patterns + recent logs in parallel — both
                    // come from the same SwiftData container, but
                    // hitting them concurrently keeps the screen
                    // responsive on first load.
                    async let patternsTask: [DetectedPattern] = {
                        do {
                            let signals = try await menstrualLocal.detectPatterns()
                            return signals.compactMap(BodyPatternsFeature.makePattern(from:))
                        } catch {
                            return []
                        }
                    }()
                    async let recentTask: [RecentSymptomEntry] = {
                        (try? await menstrualLocal.recentSymptoms(60)) ?? []
                    }()

                    let patterns = await patternsTask
                    let recent = await recentTask
                    let active = patterns.filter { !$0.isEmerging }
                    let emerging = patterns.filter { $0.isEmerging }
                    await send(.patternsLoaded(active: active, emerging: emerging))
                    await send(.recentLogsLoaded(recent))
                }

            case let .patternsLoaded(active, emerging):
                state.isLoading = false
                state.active = active
                state.emerging = emerging
                // Why Engine: recompute the closing-card synthesis
                // every time the pattern set changes. Pure call —
                // no SwiftData, no I/O — so safe inside the reducer.
                state.overviewReading = BodyPatternsReadingEngine.overviewReading(
                    active: active,
                    emerging: emerging
                )
                return .none

            case let .recentLogsLoaded(logs):
                state.recentLogs = logs
                return .none

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case .logSymptomsTapped:
                return .send(.delegate(.logSymptoms))

            case let .recentLogTapped(date, symptomRaw):
                return .send(.delegate(.logSymptomsForDate(date, symptomRaw: symptomRaw)))

            case let .patternTapped(pattern):
                state.presentedDestination = .patternDetail(pattern)
                return .none

            case .howItWorksTapped:
                state.presentedDestination = .howPatternsWork
                return .none

            case .whenToSeeDoctorTapped:
                state.presentedDestination = .whenToSeeDoctor
                return .none

            case .infoTapped:
                state.presentedDestination = .about
                return .none

            case .destinationDismissed:
                state.presentedDestination = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Mapping (Phase 2)

    /// Map a raw `PatternDetector.RawPatternSignal` to the UI-layer
    /// `DetectedPattern`. Returns nil when the symptom type isn't in
    /// the known `SymptomType` enum (defensive — shouldn't happen in
    /// practice, but a stale DB row shouldn't crash the screen).
    static func makePattern(from signal: PatternDetector.RawPatternSignal) -> DetectedPattern? {
        guard let symptomType = SymptomType(rawValue: signal.symptomTypeRaw) else { return nil }
        guard let phase = mapPhase(signal.phase) else { return nil }

        let editorial = makeEditorial(
            phase: signal.phase,
            dayRange: signal.dayRange,
            occurrences: signal.occurrences,
            isEmerging: signal.isEmerging
        )

        // Stable ID: type + phase uniquely identify a signal.
        let id = "pattern.\(signal.symptomTypeRaw).\(signal.phase.rawValue)"

        return DetectedPattern(
            id: id,
            symptomTypeRaw: signal.symptomTypeRaw,
            symptomDisplayName: symptomType.displayName,
            symptomIconName: symptomType.sfSymbol,
            phase: phase,
            occurrences: signal.occurrences,
            totalCycles: signal.totalCycles,
            dayRange: signal.dayRange,
            editorial: editorial,
            isEmerging: signal.isEmerging
        )
    }

    /// Translate engine phase → app-wide `CyclePhase`. Late never
    /// reaches here (detector strips it) — guard returns nil so the
    /// signal is silently dropped if it ever does.
    private static func mapPhase(_ phase: CyclePhaseResult) -> CyclePhase? {
        switch phase {
        case .menstrual: return .menstrual
        case .follicular: return .follicular
        case .ovulatory: return .ovulatory
        case .luteal: return .luteal
        case .late: return nil
        }
    }

    /// Phase 2 editorial copy is templated with light hormonal
    /// context per phase — Phase 3 swaps this for OpenAI-
    /// generated copy cached in SwiftData. The Phase-2 strings
    /// stay as the offline fallback.
    static func makeEditorial(
        phase: CyclePhaseResult,
        dayRange: ClosedRange<Int>,
        occurrences: Int,
        isEmerging: Bool
    ) -> String {
        let dayPhrase: String
        if dayRange.lowerBound == dayRange.upperBound {
            dayPhrase = "Day \(dayRange.lowerBound)"
        } else {
            dayPhrase = "Day \(dayRange.lowerBound) to \(dayRange.upperBound)"
        }

        if isEmerging {
            return "\(dayPhrase). One more cycle to confirm a pattern."
        }

        // Psychological / emotional voice per phase — short,
        // declarative, no diagnostic certainty. Same register
        // as the Cycle Recap / Rhythm Reflection lines: leans
        // into how the user *feels* through the cycle rather
        // than naming hormones. Day range is intentionally
        // dropped from the confirmed-pattern copy — the heatmap
        // axis + `HITS HARDEST` tile + day labels already say
        // when in the cycle this falls; the editorial slot
        // earns its keep as tonal context, not data repetition.
        switch phase {
        case .menstrual:
            return "Inward days. Energy at its lowest, body asking for rest."
        case .follicular:
            return "Mind clearing, drive returning."
        case .ovulatory:
            return "Bright, social days. Connection flows easily."
        case .luteal:
            return "Softer days. Sensitivity rising before the bleed."
        case .late:
            return "\(dayPhrase). Cycle taking its time this season."
        }
    }
}
