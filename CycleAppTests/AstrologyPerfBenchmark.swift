@testable import CycleApp
import Foundation
import Testing

@Suite("Astrology Perf Benchmark")
struct AstrologyPerfBenchmark {

    @Test("generateReport cold vs warm")
    func generatePerf() {
        AstrologyEngine.configure()

        var comps = DateComponents()
        comps.year = 2002; comps.month = 7; comps.day = 11
        comps.timeZone = TimeZone(identifier: "Europe/Bucharest")
        let birth = Calendar(identifier: .gregorian).date(from: comps)!

        // Warm-up (first call loads ephemeris from disk)
        _ = AstrologyEngine.generateReport(
            birthDate: birth,
            birthTimeHHMM: "19:00",
            city: "Iasi",
            country: "Romania",
            currentDate: Date(),
            cycleDay: 1,
            cyclePhase: .follicular
        )

        // Cold run (but files already loaded)
        var times: [Double] = []
        for _ in 0..<10 {
            let t0 = Date()
            _ = AstrologyEngine.generateReport(
                birthDate: birth,
                birthTimeHHMM: "19:00",
                city: "Iasi",
                country: "Romania",
                currentDate: Date(),
                cycleDay: 1,
                cyclePhase: .follicular
            )
            times.append(Date().timeIntervalSince(t0) * 1000)
        }

        let avg = times.reduce(0, +) / Double(times.count)
        let minT = times.min() ?? 0
        let maxT = times.max() ?? 0
        print("=== AstrologyEngine.generateReport ===")
        print(String(format: "10 runs: min=%.2fms, max=%.2fms, avg=%.2fms", minT, maxT, avg))
        print("All: \(times.map { String(format: "%.1f", $0) }.joined(separator: ", "))")

        #expect(avg < 2000)
    }
}
