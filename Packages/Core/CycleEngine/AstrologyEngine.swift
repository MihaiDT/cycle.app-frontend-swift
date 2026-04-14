import CSwissEphemeris
import Foundation
import SwissEphemeris

// MARK: - AstrologyEngine

/// Pure calculation engine — no persistence, no side effects.
/// Port of astrology_report.py using Swiss Ephemeris.
enum AstrologyEngine: Sendable {

    // MARK: - Ephemeris Setup

    static func configure() {
        JPLFileManager.setEphemerisPath()
    }

    // MARK: - Planet Positions

    static func planetPosition(at date: Date, body: AstroPlanet) -> AstroPlanetPosition {
        switch body {
        case .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto:
            let coord = Coordinate<Planet>(body: body.asPlanet!, date: date)
            return AstroPlanetPosition(
                longitude: normalizeAngle(coord.longitude),
                latitude: coord.latitude,
                speedLon: coord.speedLongitude
            )
        case .chiron:
            let coord = Coordinate<Asteroid>(body: .chiron, date: date)
            return AstroPlanetPosition(
                longitude: normalizeAngle(coord.longitude),
                latitude: coord.latitude,
                speedLon: coord.speedLongitude
            )
        case .lilith:
            // Mean Apogee (Black Moon Lilith) — use C function directly
            let jd = date.julianDate()
            var xx = [Double](repeating: 0, count: 6)
            var serr = [CChar](repeating: 0, count: 256)
            swe_calc_ut(jd, 12, SEFLG_SWIEPH | SEFLG_SPEED, &xx, &serr) // 12 = SE_MEAN_APOG
            return AstroPlanetPosition(
                longitude: normalizeAngle(xx[0]),
                latitude: xx[1],
                speedLon: xx[3]
            )
        }
    }

    static func trueNodePosition(at date: Date) -> AstroPlanetPosition {
        let coord = Coordinate<LunarNorthNode>(body: .trueNode, date: date)
        return AstroPlanetPosition(
            longitude: normalizeAngle(coord.longitude),
            latitude: coord.latitude,
            speedLon: coord.speedLongitude
        )
    }

    static func allPlanetPositions(at date: Date) -> [AstroPlanet: AstroPlanetPosition] {
        var result: [AstroPlanet: AstroPlanetPosition] = [:]
        for planet in AstroPlanet.allCases {
            result[planet] = planetPosition(at: date, body: planet)
        }
        return result
    }

    // MARK: - Houses (Placidus)

    static func computeHouses(at date: Date, latitude: Double, longitude: Double) -> (cusps: [AstroHouseCusp], angles: [String: AstroPlanetPosition]) {
        let houses = HouseCusps(date: date, latitude: latitude, longitude: longitude, houseSystem: .placidus)

        let allCusps = [
            houses.first, houses.second, houses.third, houses.fourth,
            houses.fifth, houses.sixth, houses.seventh, houses.eighth,
            houses.ninth, houses.tenth, houses.eleventh, houses.twelfth,
        ]

        var cusps: [AstroHouseCusp] = []
        for (i, cusp) in allCusps.enumerated() {
            let lon = cusp.tropical.value
            let sign = ZodiacSign.from(longitude: lon)
            cusps.append(AstroHouseCusp(
                house: i + 1,
                cuspLongitude: lon,
                sign: sign,
                degreeInSign: lon.truncatingRemainder(dividingBy: 30.0)
            ))
        }

        let ascLon = houses.ascendent.tropical.value
        let mcLon = houses.midHeaven.tropical.value
        let trueNode = trueNodePosition(at: date)

        let angles: [String: AstroPlanetPosition] = [
            "Ascendant": AstroPlanetPosition(longitude: normalizeAngle(ascLon), latitude: 0, speedLon: 0),
            "MC": AstroPlanetPosition(longitude: normalizeAngle(mcLon), latitude: 0, speedLon: 0),
            "True Node": trueNode,
        ]

        return (cusps, angles)
    }

    static func planetHouse(longitude: Double, cusps: [AstroHouseCusp]) -> Int {
        let cuspLons = cusps.map(\.cuspLongitude)
        for i in 0..<12 {
            let start = cuspLons[i]
            let end = cuspLons[(i + 1) % 12]
            if end < start {
                if longitude >= start || longitude < end { return i + 1 }
            } else {
                if longitude >= start && longitude < end { return i + 1 }
            }
        }
        return 1
    }

    // MARK: - Angle Helpers

    static func normalizeAngle(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: 360.0)
        if v < 0 { v += 360.0 }
        return v
    }

    static func smallestAngleDiff(_ a: Double, _ b: Double) -> Double {
        var diff = abs((a - b).truncatingRemainder(dividingBy: 360.0))
        if diff < 0 { diff += 360.0 }
        return min(diff, 360.0 - diff)
    }

    // MARK: - Aspect Classification

    static func classifyAspect(angleDiff: Double, customOrbs: [AstroAspect: Double]? = nil) -> (AstroAspect, Double)? {
        for aspect in AstroAspect.allCases {
            let orb = customOrbs?[aspect] ?? aspect.defaultOrb
            let delta = abs(angleDiff - aspect.targetAngle)
            if delta <= orb {
                return (aspect, delta)
            }
        }
        return nil
    }

    // MARK: - Natal Aspects

    static func computeNatalAspects(_ positions: [AstroPlanet: AstroPlanetPosition]) -> [AstroAspectHit] {
        let planets = Array(positions.keys)
        var result: [AstroAspectHit] = []
        for i in 0..<planets.count {
            for j in (i + 1)..<planets.count {
                let p1 = planets[i]
                let p2 = planets[j]
                let diff = smallestAngleDiff(positions[p1]!.longitude, positions[p2]!.longitude)
                if let (aspect, orb) = classifyAspect(angleDiff: diff) {
                    result.append(AstroAspectHit(
                        planet1: p1.rawValue,
                        planet2: p2.rawValue,
                        aspect: aspect,
                        orb: (orb * 10000).rounded() / 10000
                    ))
                }
            }
        }
        return result
    }

    // MARK: - Dignity

    static func getDignity(planet: AstroPlanet, sign: ZodiacSign) -> DignityType? {
        kPlanetaryDignity[planet]?[sign]
    }

    // MARK: - Lunar Phase

    static func lunarPhase(moonLon: Double, sunLon: Double, referenceDate: Date) -> AstroLunarPhase {
        let elongation = normalizeAngle(moonLon - sunLon)
        let illumination = (1.0 - cos(elongation * .pi / 180.0)) / 2.0
        let synodicDays = 29.530588853
        let ageDays = synodicDays * elongation / 360.0

        let phaseType: MoonPhaseType
        switch elongation {
        case 0..<22.5: phaseType = .newMoon
        case 22.5..<67.5: phaseType = .waxingCrescent
        case 67.5..<112.5: phaseType = .firstQuarter
        case 112.5..<157.5: phaseType = .waxingGibbous
        case 157.5..<202.5: phaseType = .fullMoon
        case 202.5..<247.5: phaseType = .waningGibbous
        case 247.5..<292.5: phaseType = .lastQuarter
        case 292.5..<337.5: phaseType = .waningCrescent
        default: phaseType = .newMoon
        }

        let daysToNextNew = synodicDays - ageDays
        let daysToNextFull = ((180.0 - elongation).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0) * synodicDays / 360.0

        let cal = Calendar(identifier: .gregorian)
        let nextNew = cal.date(byAdding: .day, value: Int(daysToNextNew.rounded()), to: referenceDate)!
        let nextFull = cal.date(byAdding: .day, value: Int(daysToNextFull.rounded()), to: referenceDate)!

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        let waning = elongation > 180.0
        let waxing = !waning && elongation > 0

        return AstroLunarPhase(
            type: phaseType,
            elongation: (elongation * 100).rounded() / 100,
            illuminationPct: (illumination * 10000).rounded() / 100,
            waxing: waxing,
            waning: waning,
            daysSinceNewMoon: (ageDays * 100).rounded() / 100,
            nextNewMoon: fmt.string(from: nextNew),
            nextFullMoon: fmt.string(from: nextFull)
        )
    }

    // MARK: - Void of Course Moon

    static func voidOfCourseMoon(at date: Date) -> AstroVoidOfCourse {
        let nextIngress = findSignIngress(from: date, planet: .moon, direction: 1)
        let prevIngress = findSignIngress(from: date, planet: .moon, direction: -1)

        let futureEvents = moonAspectEvents(start: date, end: nextIngress)
        let pastEvents = moonAspectEvents(start: prevIngress, end: date)

        if !futureEvents.isEmpty {
            return AstroVoidOfCourse(isVOC: false, from: nil, until: nextIngress, lastAspectBeforeVOC: nil)
        }

        let lastAspect = pastEvents.last
        return AstroVoidOfCourse(
            isVOC: true,
            from: lastAspect?.date ?? prevIngress,
            until: nextIngress,
            lastAspectBeforeVOC: lastAspect.map { "Moon \($0.aspect) \($0.planet)" }
        )
    }

    private struct MoonEvent {
        let date: Date
        let planet: String
        let aspect: String
    }

    private static func moonAspectEvents(start: Date, end: Date) -> [MoonEvent] {
        var events: [MoonEvent] = []
        var seen: Set<String> = []
        let step: TimeInterval = 3600

        var t = start
        var prevPositions = allPlanetPositions(at: t)

        while t < end {
            let t2 = min(t.addingTimeInterval(step), end)
            let curPositions = allPlanetPositions(at: t2)

            let moon1 = prevPositions[.moon]!.longitude
            let moon2 = curPositions[.moon]!.longitude

            for planet in AstroPlanet.allCases where planet != .moon {
                let p1 = prevPositions[planet]!.longitude
                let p2 = curPositions[planet]!.longitude

                for aspect in AstroAspect.allCases {
                    let f1 = smallestAngleDiff(moon1, p1) - aspect.targetAngle
                    let f2 = smallestAngleDiff(moon2, p2) - aspect.targetAngle

                    if f1 * f2 < 0 {
                        let key = "\(planet.rawValue)|\(aspect.rawValue)"
                        if !seen.contains(key) {
                            seen.insert(key)
                            events.append(MoonEvent(date: t2, planet: planet.rawValue, aspect: aspect.rawValue))
                        }
                    }
                }
            }

            t = t2
            prevPositions = curPositions
        }

        return events.sorted { $0.date < $1.date }
    }

    // MARK: - Sign Ingress Finder

    static func findSignIngress(from date: Date, planet: AstroPlanet, direction: Int) -> Date {
        let step: TimeInterval = 1800.0 * Double(direction)
        let startSign = Int(planetPosition(at: date, body: planet).longitude / 30.0)
        var probe = date

        for _ in 0..<240 {
            let next = probe.addingTimeInterval(step)
            let sign = Int(planetPosition(at: next, body: planet).longitude / 30.0)
            if sign != startSign {
                var lo = direction == 1 ? probe : next
                var hi = direction == 1 ? next : probe
                for _ in 0..<35 {
                    let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2.0)
                    let midSign = Int(planetPosition(at: mid, body: planet).longitude / 30.0)
                    if midSign == startSign {
                        lo = mid
                    } else {
                        hi = mid
                    }
                }
                return direction == 1 ? hi : lo
            }
            probe = next
        }
        return probe
    }

    // MARK: - Daily Special Events

    static func dailySpecialEvents(for date: Date) -> AstroDailyEvents {
        let cal = Calendar(identifier: .gregorian)
        var startComps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        startComps.hour = 0; startComps.minute = 0; startComps.second = 0
        let start = cal.date(from: startComps)!
        let end = start.addingTimeInterval(86400)

        var ingress: [String] = []
        var stations: [String] = []
        var eclipses: [String] = []

        for planet in AstroPlanet.allCases {
            let pStart = planetPosition(at: start, body: planet)
            let pEnd = planetPosition(at: end, body: planet)

            if Int(pStart.longitude / 30) != Int(pEnd.longitude / 30) {
                ingress.append("\(planet.rawValue) entered \(pEnd.sign.name)")
            }

            if (pStart.speedLon > 0 && pEnd.speedLon < 0) || (pStart.speedLon < 0 && pEnd.speedLon > 0) {
                let station = pEnd.speedLon < 0 ? "retrograde" : "direct"
                stations.append("\(planet.rawValue) stationed \(station)")
            }
        }

        // Eclipse check
        let noon = start.addingTimeInterval(43200)
        let moonPos = planetPosition(at: noon, body: .moon)
        let sunPos = planetPosition(at: noon, body: .sun)
        let nodePos = trueNodePosition(at: noon)

        let elong = smallestAngleDiff(moonPos.longitude, sunPos.longitude)
        let sunNode = smallestAngleDiff(sunPos.longitude, nodePos.longitude)

        if elong < 8.0 && sunNode < 18.0 {
            eclipses.append("Possible Solar Eclipse window")
        }
        if abs(elong - 180.0) < 8.0 && sunNode < 18.0 {
            eclipses.append("Possible Lunar Eclipse window")
        }

        return AstroDailyEvents(ingress: ingress, stations: stations, eclipses: eclipses, specialTransitFlags: [])
    }

    // MARK: - Transit Aspects

    static func transitAspects(
        transitPositions: [AstroPlanet: AstroPlanetPosition],
        natalPositions: [AstroPlanet: AstroPlanetPosition],
        transitingPlanets: [AstroPlanet],
        orbOverride: [AstroAspect: Double]? = nil
    ) -> [AstroTransitHit] {
        var hits: [AstroTransitHit] = []
        for tPlanet in transitingPlanets {
            guard let tPos = transitPositions[tPlanet] else { continue }
            for (nPlanet, nPos) in natalPositions {
                let diff = smallestAngleDiff(tPos.longitude, nPos.longitude)
                if let (aspect, orb) = classifyAspect(angleDiff: diff, customOrbs: orbOverride) {
                    let maxOrb = orbOverride?[aspect] ?? kTransitOrb
                    if orb <= maxOrb {
                        hits.append(AstroTransitHit(
                            transitingPlanet: tPlanet.rawValue,
                            natalPlanet: nPlanet.rawValue,
                            aspect: aspect,
                            orb: (orb * 10000).rounded() / 10000,
                            transitingRetrograde: tPos.isRetrograde
                        ))
                    }
                }
            }
        }
        return hits.sorted { $0.orb < $1.orb }
    }

    // MARK: - Special Transit Flags

    static func specialTransitFlags(_ transits: [AstroTransitHit]) -> [String] {
        var flags: Set<String> = []
        for t in transits {
            if t.transitingPlanet == "Saturn" && t.natalPlanet == "Saturn" && t.aspect == .conjunction && t.orb <= 5.0 {
                flags.insert("Saturn Return active")
            }
            if t.transitingPlanet == "Jupiter" && t.natalPlanet == "Jupiter" && t.aspect == .conjunction && t.orb <= 5.0 {
                flags.insert("Jupiter Return active")
            }
            if t.transitingPlanet == "Uranus" && t.natalPlanet == "Uranus" && t.aspect == .square && t.orb <= 3.0 {
                flags.insert("Uranus square Uranus (quarter-life trigger)")
            }
            if t.transitingPlanet == "Pluto" && (t.natalPlanet == "Sun" || t.natalPlanet == "Moon") && t.orb <= 2.0 {
                flags.insert("Pluto-\(t.natalPlanet) major transformation")
            }
        }
        return flags.sorted()
    }

    // MARK: - Chakra Activations

    static func chakraActivations(from transits: [AstroTransitHit]) -> [AstroChakraActivation] {
        var result: [AstroChakraActivation] = []
        var seen: Set<AstroChakraActivation> = []

        for tr in transits {
            guard let natalPlanet = AstroPlanet(rawValue: tr.natalPlanet),
                  let info = kChakraMap[natalPlanet] else { continue }
            let activation = AstroChakraActivation(
                chakra: info.chakra,
                activatedByTransiting: tr.transitingPlanet,
                natalTarget: tr.natalPlanet,
                aspect: tr.aspect.rawValue,
                tone: tr.aspect.tone,
                theme: info.theme
            )
            if !seen.contains(activation) {
                seen.insert(activation)
                result.append(activation)
            }
        }
        return result
    }

    // MARK: - Chinese Zodiac

    static func chineseZodiacProfile(birthDate: Date) -> ChineseZodiacProfile {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: birthDate)

        let cnyApprox = approximateChineseNewYear(year: year)
        let chineseYear = birthDate >= cnyApprox ? year : year - 1

        let idx = ((chineseYear - 1984) % 60 + 60) % 60
        let stem = kChineseStems[idx % 10]
        let animal = kChineseBranches[idx % 12]

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        return ChineseZodiacProfile(
            chineseYear: chineseYear,
            cnyDate: fmt.string(from: cnyApprox),
            animal: animal,
            element: stem.element,
            yinYang: stem.yinYang,
            stem: stem.name
        )
    }

    private static func approximateChineseNewYear(year: Int) -> Date {
        let cnyDates: [Int: (Int, Int)] = [
            2000: (2, 5), 2001: (1, 24), 2002: (2, 12), 2003: (2, 1), 2004: (1, 22),
            2005: (2, 9), 2006: (1, 29), 2007: (2, 18), 2008: (2, 7), 2009: (1, 26),
            2010: (2, 14), 2011: (2, 3), 2012: (1, 23), 2013: (2, 10), 2014: (1, 31),
            2015: (2, 19), 2016: (2, 8), 2017: (1, 28), 2018: (2, 16), 2019: (2, 5),
            2020: (1, 25), 2021: (2, 12), 2022: (2, 1), 2023: (1, 22), 2024: (2, 10),
            2025: (1, 29), 2026: (2, 17), 2027: (2, 6), 2028: (1, 26), 2029: (2, 13),
            2030: (2, 3),
        ]

        let cal = Calendar(identifier: .gregorian)
        if let (month, day) = cnyDates[year] {
            return cal.date(from: DateComponents(year: year, month: month, day: day))!
        }
        return cal.date(from: DateComponents(year: year, month: 2, day: 5))!
    }

    // MARK: - Numerology (Life Path)

    static func lifePathNumber(birthDate: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: birthDate)
        let day = cal.component(.day, from: birthDate)
        let year = cal.component(.year, from: birthDate)

        let monthR = reduceNumerology(month)
        let dayR = reduceNumerology(day)
        let yearR = reduceNumerology(String(year).compactMap(\.wholeNumberValue).reduce(0, +))
        return reduceNumerology(monthR + dayR + yearR)
    }

    private static func reduceNumerology(_ value: Int) -> Int {
        var v = value
        while v > 9 && v != 11 && v != 22 && v != 33 {
            v = String(v).compactMap(\.wholeNumberValue).reduce(0, +)
        }
        return v
    }

    // MARK: - Cycle-Moon Overlay

    static func cycleMoonOverlay(cyclePhase: CyclePhase, moonPhaseType: MoonPhaseType) -> AstroCycleMoonOverlay {
        let cBucket = cycleBucket(for: cyclePhase)
        let mBucket = moonPhaseType.growthBucket

        let result: String
        switch (cBucket, mBucket) {
        case ("growing", "growing"):
            result = "aligned in growth: positive amplification"
        case ("maximum", "maximum"):
            result = "aligned at peak: maximum energy with emotional intensity"
        case ("waning", "waning"):
            result = "aligned in decline: natural retreat and consolidation"
        case ("minimum", "minimum"):
            result = "aligned at rest: deep introspection"
        case ("growing", "waning"):
            result = "conflict: energy without direction"
        case ("waning", "growing"):
            result = "conflict: opportunity without force"
        default:
            result = "mixed alignment"
        }

        return AstroCycleMoonOverlay(result: result, cycleBucket: cBucket, moonBucket: mBucket)
    }

    private static func cycleBucket(for phase: CyclePhase) -> String {
        switch phase {
        case .follicular: "growing"
        case .ovulatory: "maximum"
        case .luteal, .late: "waning"
        case .menstrual: "minimum"
        }
    }

    // MARK: - City Lookup

    static func resolveLocation(city: String, country: String) -> AstroCityLocation? {
        guard let url = Bundle.main.url(forResource: "city_coordinates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let db = try? JSONDecoder().decode([String: CityEntry].self, from: data) else {
            return nil
        }

        let key = "\(city.lowercased().trimmingCharacters(in: .whitespaces))|\(country.lowercased().trimmingCharacters(in: .whitespaces))"
        guard let entry = db[key] else { return nil }

        return AstroCityLocation(
            city: city,
            country: country,
            latitude: entry.latitude,
            longitude: entry.longitude,
            timezone: entry.timezone
        )
    }

    private struct CityEntry: Codable {
        let latitude: Double
        let longitude: Double
        let timezone: String
    }

    // MARK: - Birth DateTime → UTC

    static func birthDateUTC(birthDate: Date, birthTimeHHMM: String, timezoneName: String) -> Date {
        let parts = birthTimeHHMM.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let tz = TimeZone(identifier: timezoneName) else { return birthDate }

        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: birthDate)

        var localComps = DateComponents()
        localComps.year = comps.year
        localComps.month = comps.month
        localComps.day = comps.day
        localComps.hour = parts[0]
        localComps.minute = parts[1]
        localComps.timeZone = tz

        return cal.date(from: localComps) ?? birthDate
    }

    // MARK: - Full Report Generator

    static func generateReport(
        birthDate: Date,
        birthTimeHHMM: String,
        city: String,
        country: String,
        currentDate: Date,
        cycleDay: Int,
        cyclePhase: CyclePhase
    ) -> AstrologyReport? {
        guard let location = resolveLocation(city: city, country: country) else { return nil }

        let birthUTC = birthDateUTC(birthDate: birthDate, birthTimeHHMM: birthTimeHHMM, timezoneName: location.timezone)
        let cal = Calendar(identifier: .gregorian)
        var noonComps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: currentDate)
        noonComps.hour = 12; noonComps.minute = 0; noonComps.second = 0
        let nowUTC = cal.date(from: noonComps)!

        // Natal
        let natalPlanets = allPlanetPositions(at: birthUTC)
        let (natalHouses, natalAngles) = computeHouses(at: birthUTC, latitude: location.latitude, longitude: location.longitude)
        let natalAspects = computeNatalAspects(natalPlanets)
        let chineseZodiac = chineseZodiacProfile(birthDate: birthDate)
        let lifePath = lifePathNumber(birthDate: birthDate)

        // Today
        let todayPlanets = allPlanetPositions(at: nowUTC)
        let retrogrades = todayPlanets.filter(\.value.isRetrograde).map(\.key.rawValue)
        let phase = lunarPhase(
            moonLon: todayPlanets[.moon]!.longitude,
            sunLon: todayPlanets[.sun]!.longitude,
            referenceDate: currentDate
        )
        let voc = voidOfCourseMoon(at: nowUTC)
        var events = dailySpecialEvents(for: currentDate)

        // Transits
        let moonTransits = transitAspects(
            transitPositions: todayPlanets, natalPositions: natalPlanets,
            transitingPlanets: [.moon], orbOverride: kMoonAspectOrbs
        )
        let fastTransits = transitAspects(
            transitPositions: todayPlanets, natalPositions: natalPlanets,
            transitingPlanets: AstroPlanet.fast
        )
        let slowOther = transitAspects(
            transitPositions: todayPlanets, natalPositions: natalPlanets,
            transitingPlanets: AstroPlanet.slow.filter { $0 != .jupiter }
        )
        let slowJupiter = transitAspects(
            transitPositions: todayPlanets, natalPositions: natalPlanets,
            transitingPlanets: [.jupiter], orbOverride: kJupiterTransitOrbs
        )
        let slowTransits = (slowOther + slowJupiter).sorted { $0.orb < $1.orb }

        // Node transits
        let trueNodePos = trueNodePosition(at: nowUTC)

        var nodeTransits: [AstroTransitHit] = []
        for (nPlanet, nPos) in natalPlanets {
            let diff = smallestAngleDiff(trueNodePos.longitude, nPos.longitude)
            if let (aspect, orb) = classifyAspect(angleDiff: diff) {
                if orb <= kTransitOrb {
                    nodeTransits.append(AstroTransitHit(
                        transitingPlanet: "True Node",
                        natalPlanet: nPlanet.rawValue,
                        aspect: aspect,
                        orb: (orb * 10000).rounded() / 10000,
                        transitingRetrograde: false
                    ))
                }
            }
        }

        let allTransits = moonTransits + fastTransits + slowTransits + nodeTransits
        let flags = specialTransitFlags(allTransits)
        let chakras = chakraActivations(from: allTransits)
        let overlay = cycleMoonOverlay(cyclePhase: cyclePhase, moonPhaseType: phase.type)

        events = AstroDailyEvents(
            ingress: events.ingress,
            stations: events.stations,
            eclipses: events.eclipses,
            specialTransitFlags: flags
        )

        // Build natal planet data
        var natalPlanetData: [String: NatalPlanetData] = [:]
        for (planet, pos) in natalPlanets {
            natalPlanetData[planet.rawValue] = NatalPlanetData(
                sign: pos.sign,
                degreeInSign: (pos.degreeInSign * 1000000).rounded() / 1000000,
                longitude: (pos.longitude * 1000000).rounded() / 1000000,
                latitude: (pos.latitude * 1000000).rounded() / 1000000,
                speedLon: (pos.speedLon * 1000000).rounded() / 1000000,
                house: planetHouse(longitude: pos.longitude, cusps: natalHouses),
                dignity: getDignity(planet: planet, sign: pos.sign)
            )
        }

        var angleData: [String: AngleNodeData] = [:]
        for (name, pos) in natalAngles {
            angleData[name] = AngleNodeData(
                sign: pos.sign,
                degreeInSign: (pos.degreeInSign * 1000000).rounded() / 1000000,
                longitude: (pos.longitude * 1000000).rounded() / 1000000
            )
        }

        var dailyPlanetData: [String: DailyPlanetData] = [:]
        for (planet, pos) in todayPlanets {
            dailyPlanetData[planet.rawValue] = DailyPlanetData(
                sign: pos.sign,
                degreeInSign: (pos.degreeInSign * 1000000).rounded() / 1000000,
                longitude: (pos.longitude * 1000000).rounded() / 1000000,
                latitude: (pos.latitude * 1000000).rounded() / 1000000,
                speedLon: (pos.speedLon * 1000000).rounded() / 1000000,
                retrograde: pos.isRetrograde,
                house: planetHouse(longitude: pos.longitude, cusps: natalHouses),
                dignity: getDignity(planet: planet, sign: pos.sign)
            )
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        let transitNodeData = TransitNodeData(
            sign: ZodiacSign.from(longitude: trueNodePos.longitude),
            degreeInSign: (trueNodePos.degreeInSign * 1000000).rounded() / 1000000,
            longitude: (trueNodePos.longitude * 1000000).rounded() / 1000000,
            house: planetHouse(longitude: trueNodePos.longitude, cusps: natalHouses)
        )

        return AstrologyReport(
            input: AstrologyReportInput(
                birthDate: fmt.string(from: birthDate),
                birthTime: birthTimeHHMM,
                city: city,
                country: country,
                timezone: location.timezone,
                currentDate: fmt.string(from: currentDate),
                cycleDay: cycleDay
            ),
            natalProfile: NatalProfile(
                planetPositions: natalPlanetData,
                houses: natalHouses,
                anglesAndNodes: angleData,
                majorAspects: natalAspects,
                chineseZodiac: chineseZodiac,
                lifePathNumber: lifePath
            ),
            dailySky: DailySky(
                planetPositions: dailyPlanetData,
                transitNode: transitNodeData,
                retrogradePlanets: retrogrades,
                moonPhase: phase,
                voidOfCourse: voc,
                specialEvents: events
            ),
            personalTransits: PersonalTransits(
                moonTransits: moonTransits,
                fastTransits: fastTransits,
                slowTransits: slowTransits,
                nodeTransits: nodeTransits
            ),
            chakraActivation: chakras,
            cycleMoonOverlay: overlay
        )
    }
}

// MARK: - AstroPlanet → SwissEphemeris Planet conversion

extension AstroPlanet {
    var asPlanet: Planet? {
        switch self {
        case .sun: .sun
        case .moon: .moon
        case .mercury: .mercury
        case .venus: .venus
        case .mars: .mars
        case .jupiter: .jupiter
        case .saturn: .saturn
        case .uranus: .uranus
        case .neptune: .neptune
        case .pluto: .pluto
        case .chiron, .lilith: nil
        }
    }
}
