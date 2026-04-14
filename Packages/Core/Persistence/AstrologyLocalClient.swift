import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - AstrologyLocalClient

struct AstrologyLocalClient: Sendable {
    var generateDailyReport: @Sendable (_ currentDate: Date, _ cycleDay: Int, _ cyclePhase: CyclePhase) async throws -> AstrologyReport
    var getCachedReport: @Sendable (_ date: Date) async throws -> AstrologyReport?
    var saveNatalChart: @Sendable (_ birthDate: Date, _ birthTime: String, _ city: String, _ country: String) async throws -> Void
    var hasNatalChart: @Sendable () async throws -> Bool
    var getNatalProfile: @Sendable () async throws -> NatalProfile?
    var resetAll: @Sendable () async throws -> Void
}

// MARK: - Dependency

extension AstrologyLocalClient: DependencyKey {
    static let liveValue = AstrologyLocalClient.live()
    static let testValue = AstrologyLocalClient.mock()
    static let previewValue = AstrologyLocalClient.mock()
}

extension DependencyValues {
    var astrologyLocal: AstrologyLocalClient {
        get { self[AstrologyLocalClient.self] }
        set { self[AstrologyLocalClient.self] = newValue }
    }
}

// MARK: - Live

extension AstrologyLocalClient {
    static func live() -> Self {
        AstrologyEngine.configure()

        return AstrologyLocalClient(
            generateDailyReport: { currentDate, cycleDay, cyclePhase in
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                // Get natal chart
                let descriptor = FetchDescriptor<NatalChartRecord>()
                guard let natal = try context.fetch(descriptor).first else {
                    throw AstrologyError.noNatalChart
                }

                // Check cache
                let startOfDay = Calendar.current.startOfDay(for: currentDate)
                var cacheDescriptor = FetchDescriptor<DailyAstrologyRecord>(
                    predicate: #Predicate { $0.date == startOfDay }
                )
                cacheDescriptor.fetchLimit = 1

                if let cached = try context.fetch(cacheDescriptor).first,
                   cached.cycleDay == cycleDay,
                   let report = try? JSONDecoder().decode(AstrologyReport.self, from: cached.reportJSON) {
                    return report
                }

                // Generate new report
                guard let report = AstrologyEngine.generateReport(
                    birthDate: natal.birthDate,
                    birthTimeHHMM: natal.birthTime,
                    city: natal.city,
                    country: natal.country,
                    currentDate: currentDate,
                    cycleDay: cycleDay,
                    cyclePhase: cyclePhase
                ) else {
                    throw AstrologyError.calculationFailed
                }

                // Cache it
                let reportData = try JSONEncoder().encode(report)

                // Remove old cache for this date
                let old = try context.fetch(FetchDescriptor<DailyAstrologyRecord>(
                    predicate: #Predicate { $0.date == startOfDay }
                ))
                for o in old { context.delete(o) }

                let record = DailyAstrologyRecord(date: startOfDay, cycleDay: cycleDay, reportJSON: reportData)
                context.insert(record)
                try context.save()

                return report
            },
            getCachedReport: { date in
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let startOfDay = Calendar.current.startOfDay(for: date)

                var descriptor = FetchDescriptor<DailyAstrologyRecord>(
                    predicate: #Predicate { $0.date == startOfDay }
                )
                descriptor.fetchLimit = 1

                guard let cached = try context.fetch(descriptor).first else { return nil }
                return try? JSONDecoder().decode(AstrologyReport.self, from: cached.reportJSON)
            },
            saveNatalChart: { birthDate, birthTime, city, country in
                guard let location = AstrologyEngine.resolveLocation(city: city, country: country) else {
                    throw AstrologyError.unknownCity(city, country)
                }

                let container = CycleDataStore.shared
                let context = ModelContext(container)

                // Remove existing
                let existing = try context.fetch(FetchDescriptor<NatalChartRecord>())
                for e in existing { context.delete(e) }

                // Compute natal profile for caching
                let birthUTC = AstrologyEngine.birthDateUTC(
                    birthDate: birthDate, birthTimeHHMM: birthTime, timezoneName: location.timezone
                )
                let natalPlanets = AstrologyEngine.allPlanetPositions(at: birthUTC)
                let (houses, angles) = AstrologyEngine.computeHouses(
                    at: birthUTC, latitude: location.latitude, longitude: location.longitude
                )
                let aspects = AstrologyEngine.computeNatalAspects(natalPlanets)
                let chinese = AstrologyEngine.chineseZodiacProfile(birthDate: birthDate)
                let lifePath = AstrologyEngine.lifePathNumber(birthDate: birthDate)

                var planetData: [String: NatalPlanetData] = [:]
                for (planet, pos) in natalPlanets {
                    planetData[planet.rawValue] = NatalPlanetData(
                        sign: pos.sign,
                        degreeInSign: pos.degreeInSign,
                        longitude: pos.longitude,
                        latitude: pos.latitude,
                        speedLon: pos.speedLon,
                        house: AstrologyEngine.planetHouse(longitude: pos.longitude, cusps: houses),
                        dignity: AstrologyEngine.getDignity(planet: planet, sign: pos.sign)
                    )
                }

                var angleData: [String: AngleNodeData] = [:]
                for (name, pos) in angles {
                    angleData[name] = AngleNodeData(
                        sign: pos.sign, degreeInSign: pos.degreeInSign, longitude: pos.longitude
                    )
                }

                let profile = NatalProfile(
                    planetPositions: planetData,
                    houses: houses,
                    anglesAndNodes: angleData,
                    majorAspects: aspects,
                    chineseZodiac: chinese,
                    lifePathNumber: lifePath
                )

                let profileJSON = try JSONEncoder().encode(profile)

                let record = NatalChartRecord(
                    birthDate: birthDate, birthTime: birthTime,
                    city: city, country: country,
                    timezone: location.timezone,
                    latitude: location.latitude, longitude: location.longitude,
                    natalProfileJSON: profileJSON
                )

                context.insert(record)
                try context.save()
            },
            hasNatalChart: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                let count = try context.fetchCount(FetchDescriptor<NatalChartRecord>())
                return count > 0
            },
            getNatalProfile: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)
                guard let record = try context.fetch(FetchDescriptor<NatalChartRecord>()).first else {
                    return nil
                }
                return try? JSONDecoder().decode(NatalProfile.self, from: record.natalProfileJSON)
            },
            resetAll: {
                let container = CycleDataStore.shared
                let context = ModelContext(container)

                let natals = try context.fetch(FetchDescriptor<NatalChartRecord>())
                for n in natals { context.delete(n) }

                let dailies = try context.fetch(FetchDescriptor<DailyAstrologyRecord>())
                for d in dailies { context.delete(d) }

                try context.save()
            }
        )
    }

    static func mock() -> AstrologyLocalClient {
        AstrologyLocalClient(
            generateDailyReport: { _, _, _ in throw AstrologyError.calculationFailed },
            getCachedReport: { _ in nil },
            saveNatalChart: { _, _, _, _ in },
            hasNatalChart: { false },
            getNatalProfile: { nil },
            resetAll: { }
        )
    }
}

// MARK: - Errors

enum AstrologyError: Error, LocalizedError {
    case noNatalChart
    case unknownCity(String, String)
    case calculationFailed

    var errorDescription: String? {
        switch self {
        case .noNatalChart: "No natal chart found. Please set your birth data first."
        case .unknownCity(let city, let country): "Unknown city: \(city), \(country)"
        case .calculationFailed: "Astrology calculation failed"
        }
    }
}
