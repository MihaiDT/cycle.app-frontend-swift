import Foundation

// MARK: - Planet Position

public struct AstroPlanetPosition: Sendable, Codable, Equatable {
    public let longitude: Double
    public let latitude: Double
    public let speedLon: Double

    public var sign: ZodiacSign { ZodiacSign.from(longitude: longitude) }
    public var degreeInSign: Double { longitude.truncatingRemainder(dividingBy: 30.0) }
    public var isRetrograde: Bool { speedLon < 0 }

    public var formatted: String {
        "\(sign.name) \(String(format: "%.2f", degreeInSign))°"
    }
}

// MARK: - Aspect Hit

public struct AstroAspectHit: Sendable, Codable, Equatable {
    public let planet1: String
    public let planet2: String
    public let aspect: AstroAspect
    public let orb: Double
}

// MARK: - Transit Hit

public struct AstroTransitHit: Sendable, Codable, Equatable {
    public let transitingPlanet: String
    public let natalPlanet: String
    public let aspect: AstroAspect
    public let orb: Double
    public let transitingRetrograde: Bool
}

// MARK: - House Cusp

public struct AstroHouseCusp: Sendable, Codable, Equatable {
    public let house: Int
    public let cuspLongitude: Double
    public let sign: ZodiacSign
    public let degreeInSign: Double
}

// MARK: - Lunar Phase

public struct AstroLunarPhase: Sendable, Codable, Equatable {
    public let type: MoonPhaseType
    public let elongation: Double
    public let illuminationPct: Double
    public let waxing: Bool
    public let waning: Bool
    public let daysSinceNewMoon: Double
    public let nextNewMoon: String
    public let nextFullMoon: String
}

public enum MoonPhaseType: String, Sendable, Codable, Equatable {
    case newMoon = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case fullMoon = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"

    public var growthBucket: String {
        switch self {
        case .waxingCrescent, .firstQuarter, .waxingGibbous: "growing"
        case .waningGibbous, .lastQuarter, .waningCrescent: "waning"
        case .newMoon: "minimum"
        case .fullMoon: "maximum"
        }
    }
}

// MARK: - Void of Course Moon

public struct AstroVoidOfCourse: Sendable, Codable, Equatable {
    public let isVOC: Bool
    public let from: Date?
    public let until: Date
    public let lastAspectBeforeVOC: String?
}

// MARK: - Chakra Activation

public struct AstroChakraActivation: Sendable, Codable, Equatable, Hashable {
    public let chakra: String
    public let activatedByTransiting: String
    public let natalTarget: String
    public let aspect: String
    public let tone: String
    public let theme: String
}

// MARK: - Daily Special Events

public struct AstroDailyEvents: Sendable, Codable, Equatable {
    public let ingress: [String]
    public let stations: [String]
    public let eclipses: [String]
    public let specialTransitFlags: [String]

    public var all: [String] { ingress + stations + eclipses + specialTransitFlags }
}

// MARK: - Cycle-Moon Overlay

public struct AstroCycleMoonOverlay: Sendable, Codable, Equatable {
    public let result: String
    public let cycleBucket: String
    public let moonBucket: String
}

// MARK: - City Location

public struct AstroCityLocation: Sendable, Codable, Equatable {
    public let city: String
    public let country: String
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
}

// MARK: - Full Astrology Report

public struct AstrologyReport: Sendable, Codable, Equatable {
    public let input: AstrologyReportInput
    public let natalProfile: NatalProfile
    public let dailySky: DailySky
    public let personalTransits: PersonalTransits
    public let chakraActivation: [AstroChakraActivation]
    public let cycleMoonOverlay: AstroCycleMoonOverlay
}

public struct AstrologyReportInput: Sendable, Codable, Equatable {
    public let birthDate: String
    public let birthTime: String
    public let city: String
    public let country: String
    public let timezone: String
    public let currentDate: String
    public let cycleDay: Int
}

public struct NatalProfile: Sendable, Codable, Equatable {
    public let planetPositions: [String: NatalPlanetData]
    public let houses: [AstroHouseCusp]
    public let anglesAndNodes: [String: AngleNodeData]
    public let majorAspects: [AstroAspectHit]
    public let chineseZodiac: ChineseZodiacProfile
    public let lifePathNumber: Int
}

public struct NatalPlanetData: Sendable, Codable, Equatable {
    public let sign: ZodiacSign
    public let degreeInSign: Double
    public let longitude: Double
    public let latitude: Double
    public let speedLon: Double
    public let house: Int
    public let dignity: DignityType?
}

public struct AngleNodeData: Sendable, Codable, Equatable {
    public let sign: ZodiacSign
    public let degreeInSign: Double
    public let longitude: Double
}

public struct DailySky: Sendable, Codable, Equatable {
    public let planetPositions: [String: DailyPlanetData]
    public let transitNode: TransitNodeData
    public let retrogradePlanets: [String]
    public let moonPhase: AstroLunarPhase
    public let voidOfCourse: AstroVoidOfCourse
    public let specialEvents: AstroDailyEvents
}

public struct DailyPlanetData: Sendable, Codable, Equatable {
    public let sign: ZodiacSign
    public let degreeInSign: Double
    public let longitude: Double
    public let latitude: Double
    public let speedLon: Double
    public let retrograde: Bool
    public let house: Int
    public let dignity: DignityType?
}

public struct TransitNodeData: Sendable, Codable, Equatable {
    public let sign: ZodiacSign
    public let degreeInSign: Double
    public let longitude: Double
    public let house: Int
}

public struct PersonalTransits: Sendable, Codable, Equatable {
    public let moonTransits: [AstroTransitHit]
    public let fastTransits: [AstroTransitHit]
    public let slowTransits: [AstroTransitHit]
    public let nodeTransits: [AstroTransitHit]
}
