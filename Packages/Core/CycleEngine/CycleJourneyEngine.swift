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
            let cycleLength = input.actualCycleLength ?? profileAvgCycleLength
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
}
