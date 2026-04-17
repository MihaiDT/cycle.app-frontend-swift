@testable import CycleApp
import Foundation
import Testing

// MARK: - CycleContext Factory / Late Detection / Day Math

@Suite("CycleContext — Factory")
struct CycleContextFactoryTests {

    private static func makeStatus(
        cycleDay: Int = 8,
        phase: String = "follicular",
        cycleLength: Int = 28,
        bleedingDays: Int = 5,
        nextDaysUntil: Int? = 20,
        isLate: Bool = false,
        daysLate: Int = 0,
        hasCycleData: Bool = true,
        startOffsetDays: Int = -7
    ) -> MenstrualStatusResponse {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: startOffsetDays, to: Date())!
        return MenstrualStatusResponse(
            currentCycle: CycleInfo(
                startDate: start,
                cycleDay: cycleDay,
                phase: phase,
                bleedingDays: bleedingDays
            ),
            profile: MenstrualProfileInfo(
                avgCycleLength: cycleLength,
                cycleRegularity: "regular",
                trackingSince: cal.date(byAdding: .month, value: -3, to: Date())!
            ),
            nextPrediction: nextDaysUntil.map {
                PredictionInfo(
                    predictedDate: cal.date(byAdding: .day, value: $0, to: Date())!,
                    daysUntil: $0,
                    confidenceScore: 0.85,
                    predictionRange: DateRangeInfo(
                        start: cal.date(byAdding: .day, value: $0 - 2, to: Date())!,
                        end: cal.date(byAdding: .day, value: $0 + 2, to: Date())!
                    ),
                    isLate: isLate,
                    daysLate: daysLate
                )
            },
            fertileWindow: nil,
            hasCycleData: hasCycleData
        )
    }

    @Test("nil when hasCycleData is false")
    func nilWhenNoData() {
        let status = Self.makeStatus(hasCycleData: false)
        let ctx = CycleContext.from(
            status: status, periodDays: [], predictedDays: []
        )
        #expect(ctx == nil)
    }

    @Test("Builds context with cycle metadata")
    func basicContextBuilds() {
        let status = Self.makeStatus()
        let ctx = CycleContext.from(status: status, periodDays: [], predictedDays: [])
        #expect(ctx != nil)
        #expect(ctx?.cycleLength == 28)
        #expect(ctx?.bleedingDays == 5)
    }

    @Test("Late from prediction flag propagates")
    func lateFromPrediction() {
        let status = Self.makeStatus(
            cycleDay: 30, phase: "late", nextDaysUntil: -2, isLate: true, daysLate: 2, startOffsetDays: -30
        )
        let ctx = CycleContext.from(status: status, periodDays: [], predictedDays: [])
        #expect(ctx?.isLate == true)
        #expect(ctx?.daysLate == 2)
        #expect(ctx?.currentPhase == .late)
    }

    @Test("Late from cycleDay exceeding cycleLength")
    func lateFromCycleDayOverrun() {
        // cycleDay > cycleLength triggers late detection even without prediction flag
        let status = Self.makeStatus(
            cycleDay: 32, phase: "luteal", cycleLength: 28,
            nextDaysUntil: nil, isLate: false, daysLate: 0, startOffsetDays: -32
        )
        let ctx = CycleContext.from(status: status, periodDays: [], predictedDays: [])
        #expect(ctx?.isLate == true)
        #expect(ctx?.daysLate == 4)
        #expect(ctx?.currentPhase == .late)
    }

    @Test("Reconciles wrapped cycleDay against prediction")
    func reconcileWrappedCycleDay() {
        // Server says day 1 but prediction says period is only 2 days away.
        // Expected = 28 - 2 + 1 = 27. Server gave 1 → diff > 3 → override to 27.
        let status = Self.makeStatus(cycleDay: 1, phase: "menstrual", nextDaysUntil: 2, startOffsetDays: 0)
        let ctx = CycleContext.from(status: status, periodDays: [], predictedDays: [])
        #expect(ctx?.cycleDay == 27)
    }

    @Test("Does NOT override cycleDay when difference is small")
    func preserveCycleDayWhenClose() {
        // cycleDay=25, daysUntil=4 → expected=25. Diff=0 → no override.
        let status = Self.makeStatus(cycleDay: 25, phase: "luteal", nextDaysUntil: 4, startOffsetDays: -24)
        let ctx = CycleContext.from(status: status, periodDays: [], predictedDays: [])
        #expect(ctx?.cycleDay == 25)
    }

    @Test("Uses phase from MenstrualStatusResponse")
    func phaseFromServer() {
        let status = Self.makeStatus(cycleDay: 14, phase: "ovulatory", nextDaysUntil: 14, startOffsetDays: -13)
        let ctx = CycleContext.from(status: status, periodDays: [], predictedDays: [])
        #expect(ctx?.currentPhase == .ovulatory)
    }
}

// MARK: - CycleContext — Phase Resolution

@Suite("CycleContext — Phase resolution")
struct CycleContextPhaseTests {

    private func makeContext(
        cycleDay: Int = 8,
        cycleLength: Int = 28,
        bleedingDays: Int = 5,
        periodDays: Set<String> = [],
        predictedDays: Set<String> = [],
        fertileDays: [String: FertilityLevel] = [:],
        isLate: Bool = false,
        daysLate: Int = 0
    ) -> CycleContext {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(cycleDay - 1), to: cal.startOfDay(for: Date()))!
        return CycleContext(
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            bleedingDays: bleedingDays,
            cycleStartDate: start,
            currentPhase: isLate ? .late : .follicular,
            nextPeriodIn: nil,
            fertileWindowActive: false,
            periodDays: periodDays,
            predictedDays: predictedDays,
            fertileDays: fertileDays,
            ovulationDays: [],
            isLate: isLate,
            daysLate: daysLate
        )
    }

    private func dateKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    @Test("phase(for:) returns menstrual when date is in periodDays")
    func phaseFromPeriodDays() {
        let today = Date()
        let key = dateKey(today)
        let ctx = makeContext(periodDays: [key])
        #expect(ctx.phase(for: today) == .menstrual)
    }

    @Test("phase(for:) returns ovulatory when fertileDays has date")
    func phaseFromFertileDays() {
        let today = Date()
        let key = dateKey(today)
        let ctx = makeContext(fertileDays: [key: .peak])
        #expect(ctx.phase(for: today) == .ovulatory)
    }

    @Test("phase(for:) returns late when isLate and past cycleLength")
    func phaseLate() {
        // Cycle started 35 days ago, cycleLength=28, isLate=true, daysLate=7
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -35, to: cal.startOfDay(for: Date()))!
        let ctx = CycleContext(
            cycleDay: 36, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: start, currentPhase: .late,
            nextPeriodIn: nil, fertileWindowActive: false,
            periodDays: [], predictedDays: [],
            isLate: true, daysLate: 7
        )
        #expect(ctx.phase(for: Date()) == .late)
    }

    @Test("resolvedPhase never returns menstrual from math fallback")
    func resolvedPhasePreventsMenstrualFromMath() {
        // No server period data; cycle day 3 (would be menstrual from math)
        // But server didn't confirm — so phase should be follicular.
        let ctx = makeContext(cycleDay: 3, periodDays: [])
        let phase = ctx.resolvedPhase(for: Date())
        #expect(phase == .follicular)
    }

    @Test("daysUntilPeriod falls back to cycle math when no period data")
    func daysUntilFallback() {
        let ctx = makeContext(cycleDay: 14, cycleLength: 28)
        let days = ctx.daysUntilPeriod(from: Date())
        // No server data → fallback: cycleLength - day + 1 = 28 - 14 + 1 = 15
        #expect(days == 15)
    }

    @Test("daysUntilPeriod uses server period data when available")
    func daysUntilFromServer() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let futurePeriod = cal.date(byAdding: .day, value: 10, to: today)!
        let futureKey = dateKey(futurePeriod)
        let ctx = makeContext(cycleDay: 18, periodDays: [futureKey], predictedDays: [futureKey])
        let days = ctx.daysUntilPeriod(from: today)
        #expect(days == 10)
    }
}

// MARK: - CycleContext — Effective fields

@Suite("CycleContext — Effective computations")
struct CycleContextComputedTests {

    private func makeContext(
        cycleLength: Int = 28,
        bleedingDays: Int = 5,
        cycleDay: Int = 5,
        nextPeriodIn: Int? = nil,
        periodDays: Set<String> = [],
        predictedDays: Set<String> = [],
        isLate: Bool = false,
        daysLate: Int = 0
    ) -> CycleContext {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(cycleDay - 1), to: cal.startOfDay(for: Date()))!
        return CycleContext(
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            bleedingDays: bleedingDays,
            cycleStartDate: start,
            currentPhase: isLate ? .late : .follicular,
            nextPeriodIn: nextPeriodIn,
            fertileWindowActive: false,
            periodDays: periodDays,
            predictedDays: predictedDays,
            fertileDays: [:],
            ovulationDays: [],
            isLate: isLate,
            daysLate: daysLate
        )
    }

    @Test("effectiveCycleLength uses cycleLength when no prediction")
    func effectiveCycleLengthBase() {
        let ctx = makeContext(cycleLength: 28, nextPeriodIn: nil)
        #expect(ctx.effectiveCycleLength == 28)
    }

    @Test("effectiveCycleLength extends to cover predicted period")
    func effectiveCycleLengthExtends() {
        // cycleDay=27, nextPeriodIn=5 → predicted ends day 27+5+5-1 = 36
        let ctx = makeContext(cycleLength: 28, bleedingDays: 5, cycleDay: 27, nextPeriodIn: 5)
        #expect(ctx.effectiveCycleLength == 36)
    }

    @Test("effectiveCycleLength extends to cycleDay when late")
    func effectiveCycleLengthLate() {
        // When late, extension uses cycleDay to keep current day visible
        let ctx = makeContext(
            cycleLength: 28, cycleDay: 35, nextPeriodIn: nil, isLate: true, daysLate: 7
        )
        #expect(ctx.effectiveCycleLength >= 35)
    }

    @Test("expectedPeriodDate returns nil when not late")
    func expectedNilNotLate() {
        let ctx = makeContext(isLate: false, daysLate: 0)
        #expect(ctx.expectedPeriodDate == nil)
    }

    @Test("expectedPeriodDate returns past date when late")
    func expectedPastWhenLate() {
        let ctx = makeContext(isLate: true, daysLate: 5)
        let expected = ctx.expectedPeriodDate
        #expect(expected != nil)
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: expected!, to: today).day ?? 0
        #expect(days == 5)
    }

    @Test("effectiveBleedingDays falls back to profile when no period data")
    func effectiveBleedingFallback() {
        let ctx = makeContext(bleedingDays: 5, periodDays: [])
        #expect(ctx.effectiveBleedingDays == 5)
    }

    @Test("isPeriodLateOrMissing picks up past predicted days")
    func frontendLateDetection() {
        // No confirmed period, but predicted days in the past → late
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let key = {
            let c = cal.dateComponents([.year, .month, .day], from: yesterday)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }()
        let ctx = makeContext(
            cycleDay: 29, nextPeriodIn: -1,
            periodDays: [key], predictedDays: [key], isLate: false
        )
        #expect(ctx.isPeriodLateOrMissing == true)
    }

    @Test("dateKey formats zero-padded YYYY-MM-DD")
    func dateKeyFormat() {
        let ctx = makeContext()
        let comps = DateComponents(year: 2026, month: 3, day: 7)
        let date = Calendar.current.date(from: comps)!
        #expect(ctx.dateKey(for: date) == "2026-03-07")
    }

    @Test("isConfirmedPeriod true when in periodDays and not in predictedDays")
    func isConfirmedPeriodMath() {
        let cal = Calendar.current
        let date = cal.startOfDay(for: Date())
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let ctx = makeContext(periodDays: [key], predictedDays: [])
        #expect(ctx.isConfirmedPeriod(date) == true)
    }

    @Test("isConfirmedPeriod false when in predictedDays")
    func isConfirmedPeriodFalseWhenPredicted() {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: Date()))!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let ctx = makeContext(periodDays: [key], predictedDays: [key])
        #expect(ctx.isConfirmedPeriod(date) == false)
    }
}

// MARK: - CycleContext — Equatable

@Suite("CycleContext — Equatable")
struct CycleContextEquatableTests {

    @Test("Same inputs → equal")
    func equalWhenSame() {
        let start = Calendar.current.startOfDay(for: Date())
        let a = CycleContext(
            cycleDay: 8, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: start, currentPhase: .follicular,
            nextPeriodIn: 20, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        let b = CycleContext(
            cycleDay: 8, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: start, currentPhase: .follicular,
            nextPeriodIn: 20, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        #expect(a == b)
    }

    @Test("Different cycleDay → not equal")
    func differentCycleDay() {
        let start = Calendar.current.startOfDay(for: Date())
        let a = CycleContext(
            cycleDay: 8, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: start, currentPhase: .follicular,
            nextPeriodIn: 20, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        let b = CycleContext(
            cycleDay: 14, cycleLength: 28, bleedingDays: 5,
            cycleStartDate: start, currentPhase: .follicular,
            nextPeriodIn: 20, fertileWindowActive: false,
            periodDays: [], predictedDays: []
        )
        #expect(a != b)
    }
}
