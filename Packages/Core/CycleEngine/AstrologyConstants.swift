import Foundation

// MARK: - Zodiac Signs

public enum ZodiacSign: Int, CaseIterable, Sendable, Codable {
    case aries = 0, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    public var name: String {
        switch self {
        case .aries: "Aries"
        case .taurus: "Taurus"
        case .gemini: "Gemini"
        case .cancer: "Cancer"
        case .leo: "Leo"
        case .virgo: "Virgo"
        case .libra: "Libra"
        case .scorpio: "Scorpio"
        case .sagittarius: "Sagittarius"
        case .capricorn: "Capricorn"
        case .aquarius: "Aquarius"
        case .pisces: "Pisces"
        }
    }

    static func from(longitude: Double) -> ZodiacSign {
        let index = Int(longitude / 30.0) % 12
        return ZodiacSign(rawValue: index) ?? .aries
    }
}

// MARK: - Planets

public enum AstroPlanet: String, CaseIterable, Sendable, Codable {
    case sun = "Sun"
    case moon = "Moon"
    case mercury = "Mercury"
    case venus = "Venus"
    case mars = "Mars"
    case jupiter = "Jupiter"
    case saturn = "Saturn"
    case uranus = "Uranus"
    case neptune = "Neptune"
    case pluto = "Pluto"
    case chiron = "Chiron"
    case lilith = "Lilith"

    /// Swiss Ephemeris body ID
    public var sweBody: Int32 {
        switch self {
        case .sun: 0       // SE_SUN
        case .moon: 1      // SE_MOON
        case .mercury: 2   // SE_MERCURY
        case .venus: 3     // SE_VENUS
        case .mars: 4      // SE_MARS
        case .jupiter: 5   // SE_JUPITER
        case .saturn: 6    // SE_SATURN
        case .uranus: 7    // SE_URANUS
        case .neptune: 8   // SE_NEPTUNE
        case .pluto: 9     // SE_PLUTO
        case .chiron: 15   // SE_CHIRON
        case .lilith: 12   // SE_MEAN_APOG
        }
    }

    static let fast: [AstroPlanet] = [.sun, .mercury, .venus, .mars]
    static let slow: [AstroPlanet] = [.jupiter, .saturn, .uranus, .neptune, .pluto, .chiron]
}

// MARK: - Aspects

public enum AstroAspect: String, CaseIterable, Sendable, Codable {
    case conjunction = "Conjunction"
    case opposition = "Opposition"
    case trine = "Trine"
    case square = "Square"
    case sextile = "Sextile"

    public var targetAngle: Double {
        switch self {
        case .conjunction: 0.0
        case .opposition: 180.0
        case .trine: 120.0
        case .square: 90.0
        case .sextile: 60.0
        }
    }

    public var defaultOrb: Double {
        switch self {
        case .conjunction: 8.0
        case .opposition: 8.0
        case .trine: 8.0
        case .square: 7.0
        case .sextile: 6.0
        }
    }

    public var tone: String {
        switch self {
        case .trine, .sextile: "positive"
        case .square, .opposition: "tension"
        case .conjunction: "intense"
        }
    }
}

// MARK: - Moon Aspect Orbs (tighter for Moon transits)

public let kMoonAspectOrbs: [AstroAspect: Double] = [
    .conjunction: 5.0,
    .opposition: 5.0,
    .trine: 4.0,
    .square: 4.0,
    .sextile: 3.0,
]

// MARK: - Jupiter Transit Orbs

public let kJupiterTransitOrbs: [AstroAspect: Double] = [
    .conjunction: 5.0,
    .opposition: 3.0,
    .trine: 3.0,
    .square: 3.0,
    .sextile: 3.0,
]

public let kTransitOrb: Double = 3.0

// MARK: - Chakra Map

public struct ChakraInfo: Sendable, Codable, Equatable {
    public let chakra: String
    public let theme: String
}

public let kChakraMap: [AstroPlanet: ChakraInfo] = [
    .sun: ChakraInfo(chakra: "Solar Plexus", theme: "personal power, identity"),
    .moon: ChakraInfo(chakra: "Heart + Sacral", theme: "emotions, safety, mother themes"),
    .mercury: ChakraInfo(chakra: "Throat", theme: "thinking, communication, expression"),
    .venus: ChakraInfo(chakra: "Heart", theme: "love, relationships, beauty"),
    .mars: ChakraInfo(chakra: "Solar Plexus + Root", theme: "action, physical drive"),
    .jupiter: ChakraInfo(chakra: "Sacral", theme: "expansion, creativity, abundance"),
    .saturn: ChakraInfo(chakra: "Root + Throat", theme: "discipline, structure, limits"),
    .uranus: ChakraInfo(chakra: "Third Eye", theme: "change, freedom, intuition"),
    .neptune: ChakraInfo(chakra: "Crown", theme: "spirituality, dreams, confusion"),
    .pluto: ChakraInfo(chakra: "Sacral + Root", theme: "transformation, power"),
    .chiron: ChakraInfo(chakra: "Heart + Solar Plexus", theme: "deep wound healing, vulnerability, wisdom through pain"),
    .lilith: ChakraInfo(chakra: "Sacral + Root", theme: "shadow feminine, raw power, reclaimed sexuality"),
]

// MARK: - Planetary Dignity

public enum DignityType: String, Sendable, Codable {
    case domicile
    case exaltation
    case detriment
    case fall
    case domicileExaltation = "domicile/exaltation"
    case detrimentFall = "detriment/fall"
}

public let kPlanetaryDignity: [AstroPlanet: [ZodiacSign: DignityType]] = [
    .sun: [.leo: .domicile, .aries: .exaltation, .aquarius: .detriment, .libra: .fall],
    .moon: [.cancer: .domicile, .taurus: .exaltation, .capricorn: .detriment, .scorpio: .fall],
    .mercury: [.gemini: .domicile, .virgo: .domicileExaltation, .sagittarius: .detriment, .pisces: .detrimentFall],
    .venus: [.taurus: .domicile, .libra: .domicile, .pisces: .exaltation, .aries: .detriment, .scorpio: .detriment, .virgo: .fall],
    .mars: [.aries: .domicile, .scorpio: .domicile, .capricorn: .exaltation, .libra: .detriment, .taurus: .detriment, .cancer: .fall],
    .jupiter: [.sagittarius: .domicile, .pisces: .domicile, .cancer: .exaltation, .gemini: .detriment, .virgo: .detriment, .capricorn: .fall],
    .saturn: [.capricorn: .domicile, .aquarius: .domicile, .libra: .exaltation, .cancer: .detriment, .leo: .detriment, .aries: .fall],
]

// MARK: - Chinese Zodiac

public struct ChineseZodiacProfile: Sendable, Codable, Equatable {
    public let chineseYear: Int
    public let cnyDate: String
    public let animal: String
    public let element: String
    public let yinYang: String
    public let stem: String
}

public let kChineseStems: [(name: String, element: String, yinYang: String)] = [
    ("Jia", "Wood", "Yang"), ("Yi", "Wood", "Yin"),
    ("Bing", "Fire", "Yang"), ("Ding", "Fire", "Yin"),
    ("Wu", "Earth", "Yang"), ("Ji", "Earth", "Yin"),
    ("Geng", "Metal", "Yang"), ("Xin", "Metal", "Yin"),
    ("Ren", "Water", "Yang"), ("Gui", "Water", "Yin"),
]

public let kChineseBranches: [String] = [
    "Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake",
    "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig",
]
