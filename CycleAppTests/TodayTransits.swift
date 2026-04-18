@testable import CycleApp
import Foundation
import Testing

@Suite("Today Transits")
struct TodayTransits {

    @Test("print today's planet positions")
    func today() {
        AstrologyEngine.configure()
        let now = Date()
        let positions = AstrologyEngine.allPlanetPositions(at: now)
        let trueNode = AstrologyEngine.trueNodePosition(at: now)

        func fmt(_ lon: Double, retro: Bool) -> String {
            let sign = ZodiacSign.from(longitude: lon)
            let deg = lon.truncatingRemainder(dividingBy: 30.0)
            let d = Int(deg)
            let m = Int((deg - Double(d)) * 60.0)
            return String(format: "%@ %02d°%02d'%@", sign.name, d, m, retro ? " (R)" : "")
        }

        print("=== TODAY transits (\(now)) ===")
        for planet in AstroPlanet.allCases {
            if let p = positions[planet] {
                print("\(planet.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)): \(fmt(p.longitude, retro: p.speedLon < 0))")
            }
        }
        print("True Node : \(fmt(trueNode.longitude, retro: trueNode.speedLon < 0))")
    }
}
