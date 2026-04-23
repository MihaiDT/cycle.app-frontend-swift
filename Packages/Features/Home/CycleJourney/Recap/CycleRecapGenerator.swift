import Foundation
import SwiftData

// MARK: - Background Recap Generator
//
// Standalone recap generator — split from CycleRecapGeneration.swift
// which now contains only the CycleJourneyFeature extension + DTOs.

// MARK: - Background Recap Generator

enum CycleRecapGenerator {

    static func generateForClosedCycle(_ closedCycleStart: Date) async {
        if CycleJourneyFeature.loadCachedRecap(cycleStart: closedCycleStart) != nil { return }

        do {
            let data = try await MenstrualLocalClient.liveJourneyData()()
            let summaries = CycleJourneyEngine.buildSummaries(
                inputs: data.records,
                reports: data.reports,
                profileAvgCycleLength: data.profileAvgCycleLength,
                profileAvgBleedingDays: data.profileAvgBleedingDays,
                currentCycleStartDate: data.currentCycleStartDate
            )
            let cal = Calendar.current
            guard let summary = summaries.first(where: {
                cal.isDate($0.startDate, inSameDayAs: closedCycleStart)
            }) else { return }

            await generateAndCache(summary: summary, allSummaries: summaries)
        } catch {}
    }

    static func generateMissing() async {
        do {
            let data = try await MenstrualLocalClient.liveJourneyData()()
            let summaries = CycleJourneyEngine.buildSummaries(
                inputs: data.records,
                reports: data.reports,
                profileAvgCycleLength: data.profileAvgCycleLength,
                profileAvgBleedingDays: data.profileAvgBleedingDays,
                currentCycleStartDate: data.currentCycleStartDate
            )
            await preGenerateAll(summaries: summaries)
        } catch { }
    }

    static func preGenerateAll(summaries: [JourneyCycleSummary]) async {
        for summary in summaries {
            guard !summary.isCurrentCycle else { continue }
            if CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate) != nil {
                continue
            }
            await generateAndCache(summary: summary, allSummaries: summaries)
        }
    }

    // MARK: - Internal

    private static func generateAndCache(
        summary: JourneyCycleSummary,
        allSummaries: [JourneyCycleSummary]
    ) async {
        let keyDays = extractKeyDays(for: summary)
        let moments = collectMoments(for: summary)

        if let ai = await CycleJourneyFeature.fetchRecapAI(
            summary: summary,
            allSummaries: allSummaries,
            keyDays: keyDays,
            moments: moments
        ) {
            CycleJourneyFeature.cacheRecap(ai, cycleStart: summary.startDate)
            return
        }

        // AI failed — cache the deterministic template so the user still
        // gets a story. Template can be overwritten on next successful AI
        // pass by clearing the record.
        let fallback = CycleJourneyFeature.templateRecap(
            summary: summary,
            allSummaries: allSummaries,
            keyDays: keyDays
        )
        CycleJourneyFeature.cacheRecap(fallback, cycleStart: summary.startDate)
    }

    // MARK: - Signal loading

    private static func extractKeyDays(for summary: JourneyCycleSummary) -> [KeyDay] {
        let context = ModelContext(CycleDataStore.shared)
        let cal = Calendar.current
        let cycleStart = cal.startOfDay(for: summary.startDate)
        guard let cycleEnd = cal.date(byAdding: .day, value: summary.cycleLength, to: cycleStart) else {
            return []
        }

        // Fetch all records for this cycle's date range in one pass.
        let hbiDesc = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate { $0.scoreDate >= cycleStart && $0.scoreDate < cycleEnd }
        )
        let reportDesc = FetchDescriptor<SelfReportRecord>(
            predicate: #Predicate { $0.reportDate >= cycleStart && $0.reportDate < cycleEnd }
        )
        let challengeDesc = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.date >= cycleStart && $0.date < cycleEnd && $0.status == "completed" }
        )

        let hbis = (try? context.fetch(hbiDesc)) ?? []
        let reports = (try? context.fetch(reportDesc)) ?? []
        let challenges = (try? context.fetch(challengeDesc)) ?? []

        var signals: [KeyDaySignal] = []
        for day in 1...summary.cycleLength {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: cycleStart) else { continue }
            let dayStart = cal.startOfDay(for: date)

            let hbi = hbis.first { cal.isDate($0.scoreDate, inSameDayAs: dayStart) }
                .map { Int($0.hbiAdjusted.rounded()) }
            let report = reports.first { cal.isDate($0.reportDate, inSameDayAs: dayStart) }
            let challenge = challenges.first { cal.isDate($0.date, inSameDayAs: dayStart) }

            // Skip untracked days — no HBI and no report and no challenge
            // means there's nothing to score against.
            if hbi == nil, report == nil, challenge == nil { continue }

            signals.append(KeyDaySignal(
                day: day,
                hbi: hbi,
                mood: report?.moodLevel,
                energy: report?.energyLevel,
                stress: report?.stressLevel,
                sleep: report?.sleepQuality,
                momentCategory: challenge?.challengeCategory
            ))
        }

        return KeyDayExtractor.extract(
            signals: signals,
            cycleLength: summary.cycleLength,
            bleedingDays: summary.bleedingDays
        )
    }

    private static func collectMoments(for summary: JourneyCycleSummary) -> [MomentSummary] {
        let context = ModelContext(CycleDataStore.shared)
        let cal = Calendar.current
        let cycleStart = cal.startOfDay(for: summary.startDate)
        guard let cycleEnd = cal.date(byAdding: .day, value: summary.cycleLength, to: cycleStart) else {
            return []
        }
        let desc = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.date >= cycleStart && $0.date < cycleEnd && $0.status == "completed" }
        )
        let records = (try? context.fetch(desc)) ?? []
        return records.compactMap { record -> MomentSummary? in
            let startOfDay = cal.startOfDay(for: record.date)
            let diff = cal.dateComponents([.day], from: cycleStart, to: startOfDay).day ?? 0
            let day = diff + 1
            guard day >= 1, day <= summary.cycleLength else { return nil }
            return MomentSummary(day: day, category: record.challengeCategory)
        }
    }
}
