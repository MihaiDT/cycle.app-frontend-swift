import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Today Feature › Static Helpers
//
// Case-handler + effect-factory statics lifted out of TodayFeature.swift
// so the reducer file stays focused on State / Action / body dispatch.
// Functions here are `static` (default internal) so the reducer body
// in the main file can call them.

extension TodayFeature {
    /// Single source of truth: compute phase from CycleContext and broadcast to all components.
    /// Called from both menstrualStatusLoaded and calendarEntriesLoaded — whoever has complete data first.
    static func handleLoadWellness(_ state: inout State) -> Effect<Action> {
        state.isLoadingWellnessMessage = true
        if let cached = WellnessClient.loadCached(container: CycleDataStore.shared) {
            state.wellnessMessage = WellnessClient.messageForNow(from: cached)
            state.isLoadingWellnessMessage = false
            return .none
        }
        let phase = state.cycle?.phase(for: Date())?.rawValue ?? "unknown"
        let day = state.cycle?.cycleDay ?? 1
        let daysUntil = state.cycle?.daysUntilPeriod(from: Date()) ?? 14
        let isLate = state.cycle?.isLate ?? false
        let tracked = 10 // Approximation — exact count not in profile
        return .run { send in
            let record = await WellnessClient.fetchAndCache(
                cyclePhase: phase, cycleDay: day, daysUntilPeriod: daysUntil,
                isLate: isLate, recentSymptoms: [], moodLevel: 3, energyLevel: 3,
                cyclesTracked: tracked, container: CycleDataStore.shared
            )
            let message = record.map { WellnessClient.messageForNow(from: $0) }
            await send(.wellnessMessageLoaded(message))
        }
    }

    /// Muted placeholder shown when the wellness AI fetch returns nil (network
    /// failure, backend down, etc.). Intentionally gentle — keeps the hero
    /// from collapsing to empty whitespace without screaming "error".
    static let wellnessPlaceholder = "Checking in with you soon."

    static func syncPhaseEffect(state: State) -> Effect<Action> {
        guard let cycle = state.cycle,
              let status = state.menstrualStatus else {
            return .none
        }
        let today = Calendar.current.startOfDay(for: Date())
        let cycleDay = cycle.cycleDayNumber(for: today) ?? cycle.cycleDay
        let phase = cycle.resolvedPhase(for: today)
        let displayDay = phase == .late ? cycle.effectiveDaysLate : cycleDay
        return .send(.phaseResolved(phase, displayDay))
    }

    /// Fan out HBI score to every child that subscribes. Single source,
    /// many subscribers — add a new `.send` line here when wiring up a
    /// new HBI-reactive feature.
    static func broadcastHBIEffect(_ score: HBIScore) -> Effect<Action> {
        // HBI only fans out to features that actually re-weight on it.
        // YourDay's content is now phase-driven via LensPreviewClient —
        // HBI changes don't invalidate today's preview list.
        .send(.dailyChallenge(.hbiUpdated(score)))
    }

    /// Broadcast the latest CycleContext to downstream sibling features
    /// (CycleInsights, CycleJourney) so they refresh without a tab switch.
    /// Called from `menstrualStatusLoaded` and `calendarEntriesLoaded` — both
    /// success and failure handlers. `nil` signals unavailable data so
    /// subscribers can show empty/error state instead of stale data.
    /// HomeFeature handles the delegate and forwards to siblings.
    static func broadcastCycleDataEffect(_ cycle: CycleContext?) -> Effect<Action> {
        .send(.delegate(.cycleDataUpdated(cycle)))
    }

    /// Extracted from the main `Reduce` to keep the switch small and
    /// avoid Swift type-checker timeouts on the full reducer body.
    static func handleMenstrualStatusLoaded(
        status: MenstrualStatusResponse,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingMenstrual = false
        state.menstrualStatus = status
        state.calendarState.menstrualStatus = status
        let hasCycleData = status.hasCycleData
        let localCal = Calendar.current
        if hasCycleData {
            let startDate = CalendarFeature.localDate(from: status.currentCycle.startDate)
            state.calendarState.cycleStartDate = localCal.startOfDay(for: startDate)
        }
        state.calendarState.cycleLength = status.profile.avgCycleLength ?? 28
        state.calendarState.bleedingDays = status.currentCycle.bleedingDays ?? 5

        var effects: [Effect<Action>] = []
        if !state.calendarState.hasPreloaded {
            state.calendarState.hasPreloaded = true
            effects.append(.send(.calendar(.loadCalendar)))
        }
        if !hasCycleData {
            state.yourDayState.previews = []
            state.yourDayState.currentPhase = nil
        } else if state.hasCompletedCalendarLoad {
            effects.append(Self.syncPhaseEffect(state: state))
        }
        if hasCycleData && state.wellnessMessage == nil {
            effects.append(.send(.loadWellnessMessage))
        }
        effects.append(Self.broadcastCycleDataEffect(state.cycle))
        return effects.isEmpty ? .none : .merge(effects)
    }

    /// Extracted — see `handleMenstrualStatusLoaded` for rationale.
    static func handleCalendarEntriesLoaded(
        response: MenstrualCalendarResponse,
        state: inout State
    ) -> Effect<Action> {
        var days: Set<String> = []
        var predicted: Set<String> = []
        var fertile: [String: FertilityLevel] = [:]
        var ovulation: Set<String> = []
        let cal = Calendar.current
        for entry in response.entries {
            let localDay = CalendarFeature.localDate(from: entry.date)
            let comps = cal.dateComponents([.year, .month, .day], from: localDay)
            let key = String(
                format: "%04d-%02d-%02d",
                comps.year ?? 0,
                comps.month ?? 0,
                comps.day ?? 0
            )
            switch entry.type {
            case "period":
                days.insert(key)
            case "predicted_period":
                days.insert(key)
                predicted.insert(key)
            case "fertile":
                if let levelStr = entry.fertilityLevel,
                    let level = FertilityLevel(rawValue: levelStr)
                {
                    fertile[key] = level
                }
            case "ovulation":
                ovulation.insert(key)
            default:
                break
            }
        }
        state.hasCompletedCalendarLoad = true
        let wasSyncing = state.syncStatus == .syncing
        if wasSyncing {
            state.syncStatus = .synced
        }
        let refreshedSnapshot = CycleSnapshot(
            periodDays: days,
            predictedDays: predicted,
            fertileDays: fertile,
            ovulationDays: ovulation,
            flowIntensity: state.snapshot.flowIntensity
        )
        state.snapshot = refreshedSnapshot
        state.calendarState.snapshot = refreshedSnapshot

        let cardEffect = Self.syncPhaseEffect(state: state)
        let cycleBroadcast = Self.broadcastCycleDataEffect(state.cycle)

        if state.isRefreshingCycleData {
            return .merge(
                .run { send in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.hideSyncStatus, animation: .easeOut(duration: 0.3))
                },
                cardEffect,
                cycleBroadcast
            )
        } else if wasSyncing {
            return .merge(
                .run { send in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(.hideSyncStatus, animation: .easeOut(duration: 0.3))
                },
                cardEffect,
                cycleBroadcast
            )
        }
        return .merge(cardEffect, .send(.generateMissingRecaps), cycleBroadcast)
    }

    /// Extracted — the `.merge(.run, .send)` pattern was a notable
    /// contributor to the type-checker timeout.
    static func loadDashboardEffect(hbiLocal: HBILocalClient) -> Effect<Action> {
        .merge(
            .run { send in
                let result = await Result {
                    try await hbiLocal.getDashboard()
                }
                await send(.dashboardLoaded(result))
            },
            .send(.loadMenstrualStatus)
        )
    }

    /// Extracted — two parallel fetches merged.
    static func loadMenstrualStatusEffect(
        menstrualLocal: MenstrualLocalClient
    ) -> Effect<Action> {
        .merge(
            .run { send in
                let result = await Result {
                    try await menstrualLocal.getStatus()
                }
                await send(.menstrualStatusLoaded(result))
            },
            .run { send in
                let start = Calendar.current.date(byAdding: .month, value: -24, to: Date())!
                let end = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
                let result = await Result {
                    try await menstrualLocal.getCalendar(start, end)
                }
                await send(.calendarEntriesLoaded(result), animation: .easeInOut(duration: 0.3))
            }
        )
    }

    /// Extracted — big `.run` block that confirms/removes period groups
    /// and regenerates predictions. Inlining it alongside the rest of
    /// the cases tips Swift's type-checker over the edge.
    static func handleBackgroundSyncPeriod(
        periodDays: Set<String>,
        originalPeriodDays: Set<String>,
        menstrualLocal: MenstrualLocalClient
    ) -> Effect<Action> {
        let periodGroups = EditPeriodFeature.groupConsecutivePeriods(periodDays)
        let removedDays = originalPeriodDays.subtracting(periodDays)
        return .run { send in
            if !removedDays.isEmpty {
                let datesToRemove = removedDays.compactMap { CalendarFeature.parseDate($0) }
                try? await menstrualLocal.removePeriodDays(datesToRemove)
            }
            for group in periodGroups {
                try? await menstrualLocal.confirmPeriod(
                    group.startDate, group.dayCount, nil, true
                )
            }
            if !periodGroups.isEmpty {
                try? await menstrualLocal.generatePrediction()
            }
            await send(.backgroundSyncCompleted)
        }
    }

    /// Extracted to keep the main `Reduce` switch small — Swift's type
    /// checker starts timing out when the body has too many complex
    /// `.merge` / `.run` patterns side by side.
    static func handleYourDay(
        _ action: YourDayFeature.Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .previewsLoaded:
            if state.recapBannerMonth != nil && !state.isRecapSheetVisible {
                state.isRecapSheetVisible = true
            }
            return .none
        case .delegate(.openLens(_)):
            return .send(.delegate(.openCycleInsights))
        default:
            return .none
        }
    }

    // MARK: - Echo loader
    //
    // Builds a `DayDetailPayload` for "today's cycle day, one cycle ago".
    // Walks the journey records to find the previous cycle's start date,
    // targets the matching day, then queries SwiftData for the day's
    // self-report / moment / HBI signals. Returns `nil` when the user
    // has no previous cycle to compare against.
    static func fetchEchoPayload(
        currentCycleDay: Int,
        bleedingDays: Int
    ) async -> DayDetailPayload? {
        guard currentCycleDay > 0 else { return nil }
        let data: JourneyData
        do {
            data = try await MenstrualLocalClient.liveJourneyData()()
        } catch {
            return nil
        }

        let cal = Calendar.current
        let sortedOldestFirst = data.records.sorted { $0.startDate < $1.startDate }
        guard sortedOldestFirst.count >= 2 else { return nil }
        let previousRecord = sortedOldestFirst[sortedOldestFirst.count - 2]

        let previousStart = cal.startOfDay(for: previousRecord.startDate)
        guard let targetDate = cal.date(
            byAdding: .day,
            value: currentCycleDay - 1,
            to: previousStart
        ) else { return nil }

        // Past-cycle length: prefer the actual recorded length; fall
        // back to profile average so the phase math still lands somewhere
        // sensible for older data.
        let cycleLength: Int = {
            if let actual = previousRecord.actualCycleLength {
                return actual
            }
            let current = sortedOldestFirst.last?.startDate
            if let current {
                let gap = cal.dateComponents([.day], from: previousStart, to: current).day ?? data.profileAvgCycleLength
                if gap >= 18 && gap <= 50 { return gap }
            }
            return data.profileAvgCycleLength
        }()

        let previousBleedingDays = previousRecord.bleedingDays > 0
            ? previousRecord.bleedingDays
            : bleedingDays

        let signals = fetchDaySignals(on: targetDate)
        let cycleNumber = sortedOldestFirst.count - 1 // previous cycle's ordinal

        return JourneyEchoEngine.buildEcho(
            for: targetDate,
            cycleStartDate: previousStart,
            cycleNumber: cycleNumber,
            cycleDay: currentCycleDay,
            cycleLength: cycleLength,
            bleedingDays: previousBleedingDays,
            signals: signals
        )
    }

    /// Pulls per-day signals for a given calendar date from the shared
    /// `CycleDataStore`. Returns a `DaySignals` with `nil`s wherever the
    /// user has no log — the engine treats that as "untracked".
    static func fetchDaySignals(on date: Date) -> JourneyEchoEngine.DaySignals {
        let context = ModelContext(CycleDataStore.shared)
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return JourneyEchoEngine.DaySignals()
        }

        let reportDesc = FetchDescriptor<SelfReportRecord>(
            predicate: #Predicate { $0.reportDate >= dayStart && $0.reportDate < dayEnd }
        )
        let challengeDesc = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd && $0.status == "completed" }
        )
        let hbiDesc = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate { $0.scoreDate >= dayStart && $0.scoreDate < dayEnd }
        )

        let report = (try? context.fetch(reportDesc))?.first
        let challenge = (try? context.fetch(challengeDesc))?.first
        let hbi = (try? context.fetch(hbiDesc))?.first

        return JourneyEchoEngine.DaySignals(
            mood: report?.moodLevel,
            energy: report?.energyLevel,
            stress: report?.stressLevel,
            sleep: report?.sleepQuality,
            momentCategory: challenge?.challengeCategory,
            momentTitle: challenge?.challengeTitle,
            momentValidationFeedback: challenge?.validationFeedback,
            momentValidationRating: challenge?.validationRating,
            momentPhotoThumbnail: challenge?.photoThumbnail,
            hbiAdjusted: hbi?.hbiAdjusted,
            hbiTrendVsBaseline: hbi?.trendVsBaseline
        )
    }
}
