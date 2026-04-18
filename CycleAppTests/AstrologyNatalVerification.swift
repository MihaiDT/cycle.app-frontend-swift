@testable import CycleApp
import Foundation
import Testing

@Suite("Astrology Natal Verification")
struct AstrologyNatalVerification {

    @Test("Misu natal 11.07.2002 19:00 Iași")
    func misuNatal() {
        AstrologyEngine.configure()

        var comps = DateComponents()
        comps.year = 2002
        comps.month = 7
        comps.day = 11
        comps.hour = 19
        comps.minute = 0
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "Europe/Bucharest")
        let date = Calendar(identifier: .gregorian).date(from: comps)!

        let latitude = 47.1585
        let longitude = 27.6014

        let positions = AstrologyEngine.allPlanetPositions(at: date)
        let (cusps, angles) = AstrologyEngine.computeHouses(at: date, latitude: latitude, longitude: longitude)

        func fmt(_ lon: Double) -> String {
            let sign = ZodiacSign.from(longitude: lon)
            let deg = lon.truncatingRemainder(dividingBy: 30.0)
            let d = Int(deg)
            let m = Int((deg - Double(d)) * 60.0)
            return String(format: "%@ %02d°%02d' (%.4f°)", sign.name, d, m, lon)
        }

        print("=== NATAL CHART 11.07.2002 19:00 EEST Iași ===")
        for planet in AstroPlanet.allCases {
            if let p = positions[planet] {
                let retro = p.speedLon < 0 ? " ℞" : ""
                print("\(planet.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)): \(fmt(p.longitude))\(retro)")
            }
        }
        print("\n--- Angles ---")
        if let asc = angles["Ascendant"] { print("Ascendant : \(fmt(asc.longitude))") }
        if let mc = angles["MC"] { print("MC        : \(fmt(mc.longitude))") }
        if let node = angles["True Node"] { print("True Node : \(fmt(node.longitude))") }

        print("\n--- House Cusps (Placidus) ---")
        for cusp in cusps {
            print("H\(cusp.house): \(fmt(cusp.cuspLongitude))")
        }

        #expect(positions[.sun] != nil)
    }
}
