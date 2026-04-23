import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - CalendarFeature › Helpers
//
// Static helpers + formatters extracted from CalendarFeature.swift so
// the reducer file stays focused on State / Action / body dispatch.

extension CalendarFeature {

    // MARK: - Helpers

    static let dateKeyFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    static func dateKey(_ date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    /// Parse a "yyyy-MM-dd" key back to a Date.
    static func parseDate(_ key: String) -> Date? {
        dateKeyFormatter.date(from: key)
    }

    /// Converts a server date to local midnight for the same calendar day.
    public static func localDate(from serverDate: Date) -> Date {
        let noon = serverDate.addingTimeInterval(12 * 3600)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: noon)
        return Calendar.current.date(from: comps) ?? serverDate
    }

    /// Converts a local midnight date to UTC midnight for the same calendar day.
    public static func utcDate(from localDate: Date) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        return utcCal.date(from: comps) ?? localDate
    }

    /// Parses calendar entries from the server into state period/fertile/ovulation sets.
    static func parseCalendarEntries(_ entries: [MenstrualCalendarEntry], into state: inout State) {
        var serverPeriodDays: Set<String> = []
        var serverPredictedDays: Set<String> = []
        var serverFertileDays: [String: FertilityLevel] = [:]
        var serverOvulationDays: Set<String> = []
        for entry in entries {
            let localDay = Self.localDate(from: entry.date)
            let key = Self.dateKey(localDay)
            switch entry.type {
            case "period":
                serverPeriodDays.insert(key)
            case "predicted_period":
                serverPeriodDays.insert(key)
                serverPredictedDays.insert(key)
            case "fertile":
                if let levelStr = entry.fertilityLevel,
                   let level = FertilityLevel(rawValue: levelStr) {
                    serverFertileDays[key] = level
                }
            case "ovulation":
                serverOvulationDays.insert(key)
            default: break
            }
        }
        // Synthesize predicted days from menstrual status when late
        if serverPredictedDays.isEmpty,
           let pred = state.menstrualStatus?.nextPrediction,
           pred.isLate
        {
            let predDate = CalendarFeature.localDate(from: pred.predictedDate)
            let bleed = state.bleedingDays
            let cal = Calendar.current
            for i in 0..<bleed {
                if let d = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: predDate)) {
                    let key = CalendarFeature.dateKey(d)
                    serverPeriodDays.insert(key)
                    serverPredictedDays.insert(key)
                }
            }
        }

        state.snapshot.periodDays = serverPeriodDays
        state.snapshot.predictedDays = serverPredictedDays
        state.snapshot.fertileDays = serverFertileDays
        state.snapshot.ovulationDays = serverOvulationDays
    }

    static func ariaMessage(symptoms: [String], phase: CyclePhase?) -> String {
        let hasMood = symptoms.contains(where: {
            ["anxious", "sad", "irritable", "moodSwings", "overwhelmed", "lonely"].contains($0)
        })
        let hasPain = symptoms.contains(where: {
            ["cramps", "headache", "backPain", "breastTenderness", "bodyAches"].contains($0)
        })
        let hasLowEnergy = symptoms.contains(where: {
            ["lowEnergy", "fatigue", "insomnia", "restlessSleep"].contains($0)
        })

        switch (hasMood, hasPain, hasLowEnergy, phase) {
        case (true, _, _, .menstrual):
            return
                "I noticed you're feeling emotionally heavy today. During your period, hormone shifts can amplify everything. Want to talk through it? I'm here."
        case (true, _, _, .luteal):
            return
                "The luteal phase can bring waves of emotion that feel bigger than usual. You're not imagining it — and you don't have to carry it alone."
        case (true, _, _, _):
            return
                "I see what you're feeling today. Sometimes just putting it into words helps. Want to explore this together?"
        case (_, true, _, .menstrual):
            return
                "Your body is working hard right now. I have some gentle relief ideas that might help — want me to walk you through them?"
        case (_, true, _, _):
            return
                "Pain can be draining in ways that go beyond the physical. I'd love to help you find some comfort today."
        case (_, _, true, _):
            return
                "Low energy days deserve gentleness, not guilt. I can suggest a few things that might help you recharge — shall we chat?"
        default:
            return
                "Thank you for checking in with yourself today. Tracking these patterns helps me understand you better. Want to talk about how you're feeling?"
        }
    }

    static func recomputeCycle(from state: inout State) {
        guard !state.periodDays.isEmpty else { return }
        let groups = EditPeriodFeature.groupConsecutivePeriods(state.periodDays)
        guard !groups.isEmpty else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let pastGroups = groups.filter { $0.startDate <= today }
        guard let best = pastGroups.last ?? groups.first else { return }

        state.cycleStartDate = best.startDate
        state.bleedingDays = best.dayCount
    }

    // MARK: - Phase Calculation

    public static func phaseInfo(
        for date: Date,
        cycleStartDate: Date,
        cycleLength: Int,
        bleedingDays: Int
    ) -> (phase: CyclePhase, cycleDay: Int, isPredicted: Bool)? {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: cycleStartDate)
        let diff = cal.dateComponents([.day], from: start, to: d).day ?? 0
        guard diff >= 0 else { return nil }
        let cycleIndex = diff / cycleLength
        guard cycleIndex <= 12 else { return nil }
        let dayInCycle = diff % cycleLength + 1
        let ovDay = cycleLength - 14
        let phase: CyclePhase
        switch dayInCycle {
        case 1...bleedingDays: phase = .menstrual
        case (bleedingDays + 1)...(max(bleedingDays + 1, ovDay - 2)): phase = .follicular
        case (ovDay - 1)...(ovDay + 1): phase = .ovulatory
        default: phase = .luteal
        }
        return (phase, dayInCycle, cycleIndex > 0)
    }
}
