@testable import CycleApp
import Foundation
import Testing

@Suite("Full Report Dump")
struct FullReportDump {

    @Test("dump full AstrologyReport for subject 09.12.2001 18:30 Pascani")
    func dumpReport() throws {
        AstrologyEngine.configure()

        var comps = DateComponents()
        comps.year = 2001; comps.month = 12; comps.day = 9
        comps.timeZone = TimeZone(identifier: "Europe/Bucharest")
        let birth = Calendar(identifier: .gregorian).date(from: comps)!

        guard let report = AstrologyEngine.generateReport(
            birthDate: birth,
            birthTimeHHMM: "18:30",
            city: "Pascani",
            country: "Romania",
            currentDate: Date(),
            cycleDay: 14,
            cyclePhase: .follicular
        ) else {
            Issue.record("generateReport returned nil")
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let json = String(data: data, encoding: .utf8) ?? "<encoding failed>"
        print("=== FULL ASTROLOGY REPORT ===")
        print(json)
        print("=== END ===")

        #expect(report.natalProfile.planetPositions.count > 0)
    }
}
