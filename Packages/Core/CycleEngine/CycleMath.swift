import Foundation

// MARK: - Cycle Math

/// Pure math utilities for menstrual cycle calculations.
/// Ported 1:1 from dth-backend/internal/menstrual/utils/cycle_math.go
public enum CycleMath {

    // MARK: Date Utilities

    /// Days between two dates, ignoring time component.
    public static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let s = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: s, to: e).day ?? 0
    }

    /// Add days to a date (time-component safe).
    public static func addDays(_ date: Date, _ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: date))!
    }

    /// 1-based day within a cycle (Day 1 = first day of period).
    public static func cycleDay(cycleStart: Date, date: Date) -> Int {
        daysBetween(cycleStart, date) + 1
    }

    /// Gap between two period start dates = cycle length.
    public static func cycleLength(periodStart1: Date, periodStart2: Date) -> Int {
        abs(daysBetween(periodStart1, periodStart2))
    }

    /// Start of day in the current calendar.
    public static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    // MARK: Statistics

    /// Arithmetic mean of integer values.
    public static func mean(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Sample standard deviation.
    public static func stdDev(_ values: [Int]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        let variance = values.reduce(0.0) { $0 + pow(Double($1) - avg, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }

    /// Weighted average with corresponding weights.
    public static func weightedAverage(_ values: [Double], weights: [Double]) -> Double {
        guard values.count == weights.count, !values.isEmpty else { return 0 }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return 0 }
        let weightedSum = zip(values, weights).reduce(0.0) { $0 + $1.0 * $1.1 }
        return weightedSum / totalWeight
    }

    // MARK: Cycle Phase Detection

    /// Current cycle phase based on day within cycle.
    /// Matches backend: menstrual → follicular → ovulatory → luteal.
    public static func cyclePhase(
        cycleDay: Int,
        cycleLength: Int,
        bleedingDays: Int
    ) -> CyclePhaseResult {
        let cl = max(1, cycleLength)
        let bd = max(1, min(bleedingDays, cl))
        let ovDay = max(bd + 3, cl - 14)

        if cycleDay >= 1, cycleDay <= bd {
            return .menstrual
        } else if cycleDay <= ovDay - 3 {
            return .follicular
        } else if cycleDay <= ovDay + 2 {
            return .ovulatory
        } else {
            return .luteal
        }
    }

    // MARK: Trend Detection

    /// Detect cycle length trend: -1 (shorter), 0 (stable), +1 (longer).
    public static func detectTrend(_ cycleLengths: [Int]) -> Int {
        guard cycleLengths.count >= 3 else { return 0 }

        let mid = cycleLengths.count / 2
        let recentAvg = mean(Array(cycleLengths[..<mid]))
        let olderAvg = mean(Array(cycleLengths[mid...]))
        let diff = recentAvg - olderAvg

        if abs(diff) < 1.0 { return 0 }
        return diff > 0 ? 1 : -1
    }

    // MARK: Variability Classification

    /// Classify cycle regularity from standard deviation.
    /// ≤2 days: regular, ≤4 days: somewhat_regular, >4 days: irregular.
    public static func classifyVariability(_ cycleLengths: [Int]) -> String {
        let sd = stdDev(cycleLengths)
        if sd <= 2.0 { return "regular" }
        if sd <= 4.0 { return "somewhat_regular" }
        return "irregular"
    }

    // MARK: Confidence Calculation

    /// Prediction confidence score (0.5 — 0.95).
    /// Mirrors backend: base 0.5 + cycle count + regularity + stddev + symptom data.
    public static func calculateConfidence(
        cycleCount: Int,
        regularity: String,
        hasSymptomData: Bool,
        stdDev sd: Double
    ) -> Double {
        var confidence = 0.5

        // Factor 1: Cycle count (0.0 — 0.30)
        switch cycleCount {
        case 0: confidence += 0.05
        case 1: confidence += 0.10
        case 2: confidence += 0.15
        case 3...5: confidence += 0.20
        default: confidence += 0.30
        }

        // Factor 2: Regularity (0.0 — 0.15)
        switch regularity {
        case "regular": confidence += 0.15
        case "somewhat_regular": confidence += 0.10
        default: confidence += 0.05
        }

        // Factor 3: Standard deviation (0.0 — 0.10)
        if sd <= 2.0 {
            confidence += 0.10
        } else if sd <= 4.0 {
            confidence += 0.05
        }

        // Factor 4: Symptom data (0.0 — 0.05)
        if hasSymptomData {
            confidence += 0.05
        }

        return min(0.95, confidence)
    }

    // MARK: Prediction Range

    /// Uncertainty window in days around a prediction, based on confidence and variability.
    public static func predictionRangeDays(confidence: Double, stdDev sd: Double) -> Int {
        var baseDays: Int
        if confidence >= 0.90 {
            baseDays = 1
        } else if confidence >= 0.85 {
            baseDays = 2
        } else if confidence >= 0.75 {
            baseDays = 3
        } else {
            baseDays = 4
        }

        if sd > 4.0 {
            baseDays += 2
        } else if sd > 2.0 {
            baseDays += 1
        }

        return min(7, baseDays)
    }

    // MARK: Age Variation

    /// Age-based cycle variation factor.
    /// Teens (<20): +2, Perimenopause (40-50): +1, else: 0.
    public static func ageVariationFactor(age: Int) -> Double {
        if age < 20 { return 2.0 }
        if age >= 40, age < 50 { return 1.0 }
        return 0.0
    }

    // MARK: Fertile Window (Simple)

    /// Basic fertile window estimate: ovulation = cycleLength - 14.
    /// Used when < 3 cycles of data.
    public static func simpleFertileWindow(
        cycleStart: Date,
        cycleLength: Int
    ) -> FertileWindow {
        let ovulationDay = max(10, cycleLength - 14)
        let start = addDays(cycleStart, ovulationDay - 5 - 1) // -1 for 0-index
        let peak = addDays(cycleStart, ovulationDay - 1)
        let end = addDays(cycleStart, ovulationDay + 1 - 1)
        return FertileWindow(start: start, peak: peak, end: end)
    }

    /// Ogino-Knaus fertile window (3+ cycles of data).
    /// Fertile start = shortest - 18, end = longest - 11.
    public static func oginoKnausFertileWindow(
        cycleStart: Date,
        cycleLengths: [Int]
    ) -> FertileWindow {
        guard let shortest = cycleLengths.min(), let longest = cycleLengths.max() else {
            return simpleFertileWindow(cycleStart: cycleStart, cycleLength: 28)
        }

        let fertileStartDay = max(1, shortest - 18)
        var fertileEndDay = longest - 11
        if fertileEndDay < fertileStartDay {
            fertileEndDay = fertileStartDay + 6
        }

        let avgLength = mean(cycleLengths)
        let ovulationDay = max(10, Int(round(avgLength)) - 14)

        let start = addDays(cycleStart, fertileStartDay - 1)
        let peak = addDays(cycleStart, ovulationDay - 1)
        let end = addDays(cycleStart, fertileEndDay - 1)

        return FertileWindow(start: start, peak: peak, end: end)
    }
}

// MARK: - Value Types

/// Cycle phase result — mirrors Models.CyclePhase but decoupled from UI concerns.
public enum CyclePhaseResult: String, Sendable, Equatable {
    case menstrual
    case follicular
    case ovulatory
    case luteal
}

/// Fertile window dates.
public struct FertileWindow: Sendable, Equatable {
    public let start: Date
    public let peak: Date
    public let end: Date

    public init(start: Date, peak: Date, end: Date) {
        self.start = start
        self.peak = peak
        self.end = end
    }
}
