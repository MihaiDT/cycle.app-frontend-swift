import Foundation

// MARK: - Value Types

public struct JourneyCycleInput: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date?
    public let bleedingDays: Int
    public let actualCycleLength: Int?
    public let actualDeviationDays: Int?
    public let isConfirmed: Bool

    public init(
        startDate: Date,
        endDate: Date?,
        bleedingDays: Int,
        actualCycleLength: Int?,
        actualDeviationDays: Int?,
        isConfirmed: Bool
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.bleedingDays = bleedingDays
        self.actualCycleLength = actualCycleLength
        self.actualDeviationDays = actualDeviationDays
        self.isConfirmed = isConfirmed
    }
}

public struct JourneyCycleSummary: Equatable, Sendable, Identifiable {
    public let id: Date
    public let cycleNumber: Int
    public let startDate: Date
    public let endDate: Date?
    public let cycleLength: Int
    public let bleedingDays: Int
    public let phaseBreakdown: PhaseBreakdown
    public let predictionAccuracyDays: Int?
    public let accuracyLabel: String?
    public let isCurrentCycle: Bool
    public let avgEnergy: Double?
    public let avgMood: Double?
    public let moodLabel: String?

    public struct PhaseBreakdown: Equatable, Sendable {
        public let menstrualDays: Int
        public let follicularDays: Int
        public let ovulatoryDays: Int
        public let lutealDays: Int
    }
}

public struct JourneyInsight: Equatable, Sendable {
    public let trendDirection: TrendDirection
    public let regularityLabel: String
    public let averageCycleLength: Double
    public let totalCycles: Int
    public let narrative: String

    public enum TrendDirection: String, Equatable, Sendable {
        case shortening, stable, lengthening
    }
}

public struct MissedMonth: Equatable, Sendable {
    public let name: String
    public let date: Date
}

// MARK: - Engine

public enum CycleJourneyEngine {

    public static func buildSummaries(
        inputs: [JourneyCycleInput],
        reports: [JourneyReportInput],
        profileAvgCycleLength: Int,
        profileAvgBleedingDays: Int,
        currentCycleStartDate: Date?
    ) -> [JourneyCycleSummary] {
        let cal = Calendar.current
        let sortedOldestFirst = inputs.sorted { $0.startDate < $1.startDate }
        let currentStart = currentCycleStartDate.map { CycleMath.startOfDay($0) }

        return sortedOldestFirst.enumerated().map { index, input in
            // For past cycles, derive length from gap to next cycle start if actualCycleLength is missing
            let cycleLength: Int
            if let actual = input.actualCycleLength {
                cycleLength = actual
            } else if index + 1 < sortedOldestFirst.count {
                let nextStart = sortedOldestFirst[index + 1].startDate
                let gap = cal.dateComponents([.day], from: cal.startOfDay(for: input.startDate), to: cal.startOfDay(for: nextStart)).day ?? profileAvgCycleLength
                cycleLength = (gap >= 18 && gap <= 50) ? gap : profileAvgCycleLength
            } else {
                cycleLength = profileAvgCycleLength
            }
            let bleeding = input.bleedingDays > 0 ? input.bleedingDays : profileAvgBleedingDays
            let breakdown = phaseBreakdown(cycleLength: cycleLength, bleedingDays: bleeding)
            let isCurrent = currentStart.map { CycleMath.startOfDay(input.startDate) == $0 } ?? false

            // Aggregate reports within this cycle's date range
            let cycleStart = cal.startOfDay(for: input.startDate)
            let cycleEnd = cal.date(byAdding: .day, value: cycleLength, to: cycleStart) ?? cycleStart
            let cycleReports = reports.filter { r in
                let d = cal.startOfDay(for: r.date)
                return d >= cycleStart && d < cycleEnd
            }

            let avgEnergy: Double? = cycleReports.isEmpty ? nil
                : Double(cycleReports.reduce(0) { $0 + $1.energy }) / Double(cycleReports.count)
            let avgMood: Double? = cycleReports.isEmpty ? nil
                : Double(cycleReports.reduce(0) { $0 + $1.mood }) / Double(cycleReports.count)
            let moodLabel = avgMood.map { moodDescription($0) }

            return JourneyCycleSummary(
                id: input.startDate,
                cycleNumber: index + 1,
                startDate: input.startDate,
                endDate: input.endDate,
                cycleLength: cycleLength,
                bleedingDays: bleeding,
                phaseBreakdown: breakdown,
                predictionAccuracyDays: input.actualDeviationDays,
                accuracyLabel: input.actualDeviationDays.map { accuracyLabel(deviationDays: $0) },
                isCurrentCycle: isCurrent,
                avgEnergy: avgEnergy,
                avgMood: avgMood,
                moodLabel: moodLabel
            )
        }
    }

    private static func moodDescription(_ avg: Double) -> String {
        switch avg {
        case 4.5...: return "Great"
        case 3.5..<4.5: return "Good"
        case 2.5..<3.5: return "Okay"
        case 1.5..<2.5: return "Low"
        default: return "Rough"
        }
    }

    public static func buildInsight(summaries: [JourneyCycleSummary]) -> JourneyInsight? {
        let completed = summaries.filter { !$0.isCurrentCycle }
        guard completed.count >= 2 else { return nil }

        let lengths = completed.map(\.cycleLength)
        let trend = CycleMath.detectTrend(lengths)
        let regularity = CycleMath.classifyVariability(lengths)
        let avg = CycleMath.mean(lengths)

        let direction: JourneyInsight.TrendDirection
        switch trend {
        case -1: direction = .shortening
        case 1: direction = .lengthening
        default: direction = .stable
        }

        let regularityDisplay = regularity.replacingOccurrences(of: "_", with: " ")
        let avgDisplay = avg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(avg))"
            : String(format: "%.1f", avg)

        let narrative = "Your cycles are \(regularityDisplay), averaging \(avgDisplay) days. Your pattern is \(direction.rawValue)."

        return JourneyInsight(
            trendDirection: direction,
            regularityLabel: regularity,
            averageCycleLength: avg,
            totalCycles: completed.count,
            narrative: narrative
        )
    }

    /// Find months where a prediction existed but no cycle was confirmed.
    public static func findMissedMonths(
        predictions: [JourneyPredictionInput],
        confirmedStartDates: [Date]
    ) -> [MissedMonth] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        let confirmedMonths = Set(confirmedStartDates.map { date -> String in
            let comps = cal.dateComponents([.year, .month], from: date)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)"
        })

        var missed: [MissedMonth] = []
        var seenKeys: Set<String> = []
        for pred in predictions {
            let predDate = cal.startOfDay(for: pred.predictedDate)
            guard predDate < today else { continue }
            let comps = cal.dateComponents([.year, .month], from: predDate)
            let key = "\(comps.year ?? 0)-\(comps.month ?? 0)"
            if !confirmedMonths.contains(key) && !seenKeys.contains(key) {
                seenKeys.insert(key)
                let monthStart = cal.date(from: comps) ?? predDate
                missed.append(MissedMonth(name: formatter.string(from: predDate), date: monthStart))
            }
        }
        return missed
    }

    public static func phaseBreakdown(
        cycleLength: Int,
        bleedingDays: Int
    ) -> JourneyCycleSummary.PhaseBreakdown {
        var menstrual = 0
        var follicular = 0
        var ovulatory = 0
        var luteal = 0

        for day in 1...cycleLength {
            let phase = CycleMath.cyclePhase(cycleDay: day, cycleLength: cycleLength, bleedingDays: bleedingDays)
            switch phase {
            case .menstrual: menstrual += 1
            case .follicular: follicular += 1
            case .ovulatory: ovulatory += 1
            case .luteal: luteal += 1
            case .late: break
            }
        }

        return JourneyCycleSummary.PhaseBreakdown(
            menstrualDays: menstrual,
            follicularDays: follicular,
            ovulatoryDays: ovulatory,
            lutealDays: luteal
        )
    }

    public static func accuracyLabel(deviationDays: Int) -> String {
        let d = abs(deviationDays)
        switch d {
        case 0: return "Exact"
        case 1: return "\u{00B1}1 day"
        case 2...3: return "\u{00B1}\(d) days"
        default: return "\(d) days off"
        }
    }

    /// Data-driven cycle name. Non-judgmental, poetic, personal.
    /// Uses mood+energy when available, falls back to cycle characteristics fingerprint.
    public static func cycleName(for summary: JourneyCycleSummary) -> String {
        if let mood = summary.avgMood, let energy = summary.avgEnergy {
            return moodEnergyName(mood: mood, energy: energy, seed: cycleSeed(summary))
        }
        return characteristicName(for: summary)
    }

    /// Short human reason explaining why the cycle got its name.
    /// Returns nil when no mood/energy data — don't fake a reason.
    public static func cycleNameReason(for summary: JourneyCycleSummary) -> String? {
        guard let mood = summary.avgMood, let energy = summary.avgEnergy else { return nil }
        let moodWord = mood >= 4 ? "great" : mood >= 3 ? "good" : mood >= 2 ? "low" : "tough"
        let energyWord = energy >= 4 ? "high" : energy >= 3 ? "moderate" : "low"
        return "\(energyWord) energy, \(moodWord) mood"
    }

    // MARK: - Mood+Energy Names (primary)

    private static func moodEnergyName(mood: Double, energy: Double, seed: Int) -> String {
        let highMood = mood >= 3.5
        let highEnergy = energy >= 3.5
        let names: [String] = switch (highMood, highEnergy) {
        case (true, true):
            ["Radiant", "Luminous", "Golden", "Vivid", "Bright"]
        case (true, false):
            ["Serene", "Gentle", "Soft Glow", "Still Waters", "Calm"]
        case (false, true):
            ["Bold", "Fierce", "Untamed", "Electric", "Wild"]
        case (false, false):
            ["Cocoon", "Stillness", "Ember", "Inward", "Rest"]
        }
        return names[seed % names.count]
    }

    // MARK: - Characteristic Names (fallback)

    private static func characteristicName(for summary: JourneyCycleSummary) -> String {
        let seed = cycleSeed(summary)
        let bd = summary.phaseBreakdown
        let total = bd.menstrualDays + bd.follicularDays + bd.ovulatoryDays + bd.lutealDays
        guard total > 0 else { return "Cycle" }

        // Find the dominant phase (largest proportion)
        let phases: [(days: Int, trait: CycleTrait)] = [
            (bd.menstrualDays, .depth),
            (bd.follicularDays, .rise),
            (bd.ovulatoryDays, .peak),
            (bd.lutealDays, .settle),
        ]
        let dominant = phases.max(by: { $0.days < $1.days })?.trait ?? .rise

        // Cycle length character
        let lengthChar: CyclePace
        if summary.cycleLength < 26 { lengthChar = .swift }
        else if summary.cycleLength > 30 { lengthChar = .long }
        else { lengthChar = .steady }

        // Bleeding intensity
        let bleedChar: BleedWeight = summary.bleedingDays >= 6 ? .heavy : summary.bleedingDays <= 3 ? .light : .normal

        return traitName(dominant: dominant, pace: lengthChar, bleed: bleedChar, seed: seed)
    }

    private enum CycleTrait { case depth, rise, peak, settle }
    private enum CyclePace { case swift, steady, long }
    private enum BleedWeight { case light, normal, heavy }

    private static func traitName(dominant: CycleTrait, pace: CyclePace, bleed: BleedWeight, seed: Int) -> String {
        // Each combination maps to a pool of 3+ names for variety
        let pool: [String] = switch dominant {
        case .depth:
            switch pace {
            case .swift:  ["Quicksilver", "Flash", "Spark"]
            case .steady: ["Tide", "Anchor", "Root"]
            case .long:   ["Deep Well", "Slow Burn", "Night Sky"]
            }
        case .rise:
            switch pace {
            case .swift:  ["Dart", "Breeze", "Swift Wing"]
            case .steady: ["Bloom", "New Leaf", "Meadow"]
            case .long:   ["Long Dawn", "Unfolding", "Slow Bloom"]
            }
        case .peak:
            switch pace {
            case .swift:  ["Flare", "Bright Flash", "Spark"]
            case .steady: ["Sunlit", "Crest", "High Noon"]
            case .long:   ["Long Glow", "Golden Hour", "Horizon"]
            }
        case .settle:
            switch pace {
            case .swift:  ["Dusk", "Hush", "Whisper"]
            case .steady: ["Amber", "Hearth", "Lantern"]
            case .long:   ["Wander", "Drift", "Moonpath"]
            }
        }

        // Use bleed weight to shift the index for extra variety
        let bleedOffset = switch bleed {
        case .light: 0
        case .normal: 1
        case .heavy: 2
        }
        return pool[(seed + bleedOffset) % pool.count]
    }

    /// Deterministic seed from cycle data — stable across refreshes
    private static func cycleSeed(_ summary: JourneyCycleSummary) -> Int {
        let datePart = Int(summary.startDate.timeIntervalSince1970 / 86400)
        return abs(datePart &+ summary.cycleLength &* 7 &+ summary.bleedingDays &* 13)
    }
}
