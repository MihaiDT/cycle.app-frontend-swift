import Foundation

// MARK: - Bond
//
// A person the user adds to their circle — partner, friend, anyone
// they choose. Name is optional via `isAnonymous` (the "prefer not to
// say" path). Birth date + time + place are captured for the future
// chakra / astral transit engine that will compute a reading between
// the user and this bond on multiple themes. Mock-only for now —
// everything lives in memory inside `MeFeature.State`.

public struct BondBirthPlace: Equatable, Sendable, Hashable {
    public let placeId: String
    public let displayName: String
    public let latitude: Double
    public let longitude: Double
    public let timezone: String?

    public init(
        placeId: String,
        displayName: String,
        latitude: Double,
        longitude: Double,
        timezone: String?
    ) {
        self.placeId = placeId
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }
}

public struct Bond: Equatable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var isAnonymous: Bool
    public var birthDate: Date
    public var birthTime: Date
    public var birthPlace: BondBirthPlace
    public var themes: [BondTheme]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        isAnonymous: Bool,
        birthDate: Date,
        birthTime: Date,
        birthPlace: BondBirthPlace,
        themes: [BondTheme] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isAnonymous = isAnonymous
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.birthPlace = birthPlace
        self.themes = themes
        self.createdAt = createdAt
    }

    public var displayName: String { isAnonymous ? "Anonymous" : name }
}

public struct BondTheme: Equatable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let body: String
    public let accentRole: AccentRole

    public enum AccentRole: String, Sendable, Equatable, Hashable, CaseIterable {
        case period
        case follicular
        case fertile
        case luteal
    }

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        body: String,
        accentRole: AccentRole
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.accentRole = accentRole
    }
}

// MARK: - Mock factories

extension Bond {
    public static func mock(seed: Int = 0) -> Bond {
        let presets: [(name: String, anonymous: Bool, place: BondBirthPlace, dateOffset: TimeInterval, timeHour: Int, timeMin: Int)] = [
            (
                "Maya",
                false,
                BondBirthPlace(
                    placeId: "mock-buc",
                    displayName: "Bucharest, Romania",
                    latitude: 44.43,
                    longitude: 26.10,
                    timezone: "Europe/Bucharest"
                ),
                -30 * 365 * 24 * 3600,
                4, 22
            ),
            (
                "Andrei",
                false,
                BondBirthPlace(
                    placeId: "mock-lis",
                    displayName: "Lisbon, Portugal",
                    latitude: 38.72,
                    longitude: -9.14,
                    timezone: "Europe/Lisbon"
                ),
                -34 * 365 * 24 * 3600,
                22, 8
            ),
            (
                "",
                true,
                BondBirthPlace(
                    placeId: "mock-kyo",
                    displayName: "Kyoto, Japan",
                    latitude: 35.01,
                    longitude: 135.77,
                    timezone: "Asia/Tokyo"
                ),
                -37 * 365 * 24 * 3600,
                14, 30
            ),
        ]
        let p = presets[seed % presets.count]
        let cal = Calendar(identifier: .gregorian)
        let time = cal.date(bySettingHour: p.timeHour, minute: p.timeMin, second: 0, of: .now) ?? .now
        return Bond(
            name: p.name,
            isAnonymous: p.anonymous,
            birthDate: Date(timeIntervalSinceNow: p.dateOffset),
            birthTime: time,
            birthPlace: p.place,
            themes: BondTheme.mockSet(seed: seed)
        )
    }
}

extension BondTheme {
    public static func mockSet(seed: Int = 0) -> [BondTheme] {
        [
            BondTheme(
                title: "How you flow together",
                subtitle: "Rhythm",
                body: """
                Two cycles brushing past one another — your luteal phase lands almost exactly on their follicular dawn. \
                For about ten days a month you read each other through opposite weather: you are gathering inward, they are reaching out. \
                That asymmetry is not friction, it is texture. The third and fourth week are where the overlap softens; \
                shared meals, slow walks, anything that does not demand a decision tends to land well there. \
                Avoid scheduling hard conversations in your week one or their week three — you will both be too thin-skinned to hear what is actually meant.
                """,
                accentRole: .period
            ),
            BondTheme(
                title: "Conversation patterns",
                subtitle: "Voice",
                body: """
                They speak in arcs — long, recursive, returning to the same image from three angles. \
                You reply in pulses — short, declarative, the next beat already loading. \
                When you try to match their rhythm you flatten yourself; when they try to match yours they sound clipped. \
                The overlap reads like jazz when neither of you is performing — you trust the silence between phrases and they trust the pulse beneath theirs. \
                The cleanest signal that something is off: you both start narrating instead of asking. Pull back to questions when that happens.
                """,
                accentRole: .follicular
            ),
            BondTheme(
                title: "Energy exchange",
                subtitle: "Reciprocity",
                body: """
                Your sacral hands theirs the lantern; theirs returns it half a beat later, warmer for having been held. \
                You give first, almost reflexively, and you give in the form of attention — noticing the unspoken, anticipating the want. \
                They give in the form of presence — they will sit beside the thing rather than try to fix it. \
                The exchange is even, but the currencies are different, and trouble starts when one of you starts auditing in the other's currency. \
                The corrective is naming what you actually received, in the form it arrived, not the form you wanted it in.
                """,
                accentRole: .fertile
            ),
            BondTheme(
                title: "Friction zones",
                subtitle: "Edges",
                body: """
                Mercury squares your moon at the edge of every disagreement — assume they mean a question even when it lands like a verdict. \
                The fights are almost always about pace: one of you is ready to resolve, the other still circling the wound. \
                Quick apologies tend to bypass what actually needs to be said and leave a residue. \
                Slow apologies — naming the thing twice, once for what happened and once for what it touched — clear the air for weeks. \
                If a conversation is going nowhere after twenty minutes, sleep on it. The morning version is almost always the truer one.
                """,
                accentRole: .luteal
            ),
            BondTheme(
                title: "Growth edges",
                subtitle: "Becoming",
                body: """
                Both your Saturns are listening this season. Slow promises hold; fast ones evaporate before sundown. \
                The bond is in a chapter where what you build matters more than what you say you will build — \
                small rituals you actually keep are worth more than ambitious plans you both half-mean. \
                Your edge: trusting that being witnessed in the unglamorous parts is also a form of being loved. \
                Their edge: letting themselves be the one who needs something, not just the one who shows up.
                """,
                accentRole: .period
            ),
            BondTheme(
                title: "Seasons ahead",
                subtitle: "Forecast",
                body: """
                The next two cycles are weather you have not seen together yet — one of you is moving through a Jupiter return, \
                the other is wrapping a Saturn passage. Expect to feel out of phase before you feel in phase again. \
                This is the season to renegotiate, not to renounce; the patterns you set now will hold for about ten months. \
                When the rhythm finally syncs again — and it will — it will feel both familiar and entirely new, like a song you knew in another key.
                """,
                accentRole: .follicular
            ),
        ]
    }
}
