import SwiftUI

// MARK: - Design Colors (Figma Palette)

public enum DesignColors {
    // MARK: - Backgrounds
    public static let background = Color(hex: 0xFDFCF7)  // Ivory Whisper - fundal
    public static let backgroundElegant = Color(hex: 0xFDFCF7)  // Champagne Silk - eleganta, confort
    public static let cardWarm = Color(hex: 0xF7F2E8)  // Warm card surface — stat boxes & how-to card
    public static let cardGradientStart = Color(hex: 0xF2EBDC)  // Deep cream — start of the glow card gradient
    public static let cardGradientEnd = Color(hex: 0xE6D4C4)  // Warm sandstone — end of the glow card gradient

    // MARK: - Semantic Opacities
    /// Primary shadow pass on elevated CTAs (big ambient drop).
    public static let shadowOpacityPrimary: Double = 0.22
    /// Secondary shadow pass on elevated CTAs (tight contact shadow).
    public static let shadowOpacitySecondary: Double = 0.12
    /// 1px borders on warm cream cards — barely there, but present.
    public static let borderOpacitySubtle: Double = 0.07
    /// Hairline dividers inside cards (between tips, rows, etc.).
    public static let dividerOpacity: Double = 0.08

    // MARK: - Text Colors
    public static let text = Color(hex: 0x5C4A3B)  // Cocoa Dark - text important
    public static let textPrincipal = Color(hex: 0x7A5F50)  // Deep Cocoa - text principal/contrast
    public static let textSecondary = Color(hex: 0x6E6A68)  // Soft Charcoal - text secundar (≈5.2:1 on ivory, AA)
    /// Warm mid-grey used for placeholder copy, small counters, and muted labels.
    /// Darkened from `#A69F98` → `#777069` to reach WCAG AA (≈4.77:1) on the ivory
    /// background and warm card surfaces. Still reads as "soft", not black.
    public static let textPlaceholder = Color(hex: 0x777069)  // Warm Grey - placeholder (AA on ivory)
    /// Purely decorative soft grey preserved for non-text usages (strokes, fills,
    /// skeletons). Do not use as standalone text on light backgrounds — fails AA.
    public static let textPlaceholderMuted = Color(hex: 0xA69F98)
    public static let textCard = Color(hex: 0xB49B87)  // Rose Taupe - text secundar/card-uri

    // MARK: - Accent Colors
    public static let accent = Color(hex: 0xEBCFC3)  // Soft Blush - primary accent butoane principale
    public static let accentSecondary = Color(hex: 0xD6A59A)  // Dusty Rose - accent secundar, hover, active
    /// Decorative terracotta — used for fills, borders, glows, ambient tints.
    /// At `#C18F7D` this is ≈2.7:1 on the ivory background (fails AA/AA Large
    /// as text). Use `accentWarmText` when rendering small copy in this hue.
    public static let accentWarm = Color(hex: 0xC18F7D)  // Terracotta Warm - alert/highlight bland
    /// Text-safe terracotta variant — darkened from `#C18F7D` → `#8E6052` so
    /// small labels rendered in the warm accent hue (e.g. "TODAY", "Today"
    /// jump button, micro pills) hit WCAG AA (≈5.17:1 on ivory). Preserves
    /// the terracotta family so the brand doesn't shift.
    public static let accentWarmText = Color(hex: 0x8E6052)

    // MARK: - Structure Colors
    public static let structure = Color(hex: 0xDECBC1)  // Warm Sandstone - structura vizuala
    public static let divider = Color(hex: 0xD8D3CB)  // Moonlit Grey - divider/borders subtle

    // MARK: - Rose Taupe - for periods/feminine accents
    public static let roseTaupe = Color(hex: 0xC8ADA7)  // Rose Taupe - accent feminin, cald
    public static let roseTaupeLight = Color(hex: 0xD6C5C0)  // Rose Taupe lighter

    // MARK: - Gradient Colors (mapped to palette)
    public static let gradientLight = Color(hex: 0xDECBC1)  // Warm Sandstone
    public static let gradientMid = Color(hex: 0xB49B87)  // Rose Taupe (text card)
    public static let gradientDark = Color(hex: 0x5C4A3B)  // Cocoa Dark

    // MARK: - Glass Effect Colors (for liquid glass UI)
    public static let glassGray = Color(hex: 0xA69F98)  // Warm Grey
    public static let glassDarkTint = Color(hex: 0x5C4A3B)  // Cocoa Dark
    public static let glassPeach = Color(hex: 0xEBCFC3)  // Soft Blush
    public static let glassInnerGlow = Color(hex: 0xFDFCF7)  // Ivory Whisper

    // MARK: - Journey / Recap
    public static let warmBrown = Color(red: 0.40, green: 0.33, blue: 0.28)

    // MARK: - Hero / Surface Tints
    /// Warm cream surface used as the top of the Today hero gradient.
    public static let heroCreamTop = Color(hex: 0xFEFCF7)
    /// Warm cream surface used as the bottom of the Today hero gradient (peach-cream).
    public static let heroCreamBottom = Color(red: 0.95, green: 0.91, blue: 0.88)
    /// Soft ivory/peach background used for the Journey screen and Pattern Insights sheet.
    public static let journeyBackground = Color(red: 0.97, green: 0.94, blue: 0.91)
    /// Skeleton placeholder tint used during card loading states.
    public static let skeletonBackground = Color(red: 0.94, green: 0.93, blue: 0.91)
    /// Gradient terminator used in onboarding preview backgrounds (peach-mauve).
    public static let onboardingPreviewTint = Color(red: 0.85, green: 0.75, blue: 0.72)

    // MARK: - Status Colors
    /// Success / saved confirmation state (e.g., symptom sheet save button).
    public static let statusSuccess = Color(hex: 0x5BA36B)

    // MARK: - Calendar Glyph Colors (native canvas drawing)
    /// Deep rose used to fill confirmed period days in the calendar grid.
    public static let calendarPeriodGlyph = Color(red: 0.79, green: 0.25, blue: 0.38)
    /// Warm sand used to fill fertile-window days in the calendar grid.
    public static let calendarFertileGlyph = Color(red: 0.757, green: 0.561, blue: 0.490)
    /// Muted cocoa used for calendar day numbers (appears at 0.55 alpha in canvas).
    public static let calendarDayText = Color(red: 0.36, green: 0.29, blue: 0.23)
    /// Terracotta accent used to ring the "today" cell in the calendar.
    public static let calendarTodayRing = Color(red: 0.76, green: 0.56, blue: 0.49)

    // MARK: - Aria Recap (story page gradients)
    public static let recapMenstrualStart = Color(red: 0.72, green: 0.36, blue: 0.40)
    public static let recapMenstrualEnd = Color(red: 0.82, green: 0.52, blue: 0.45)
    public static let recapFollicularStart = Color(red: 0.78, green: 0.48, blue: 0.40)
    public static let recapFollicularEnd = Color(red: 0.88, green: 0.65, blue: 0.50)
    public static let recapOvulatoryStart = Color(red: 0.55, green: 0.42, blue: 0.65)
    public static let recapOvulatoryEnd = Color(red: 0.70, green: 0.58, blue: 0.75)
    public static let recapLutealStart = Color(red: 0.75, green: 0.55, blue: 0.30)
    public static let recapLutealEnd = Color(red: 0.85, green: 0.70, blue: 0.42)
    public static let recapAriaStart = Color(red: 0.32, green: 0.23, blue: 0.20)
    public static let recapAriaEnd = Color(red: 0.50, green: 0.36, blue: 0.30)
    /// Warm start of the Aria avatar gradient used on the recap "Ask Aria" page.
    public static let ariaBadgeStart = Color(red: 0.85, green: 0.55, blue: 0.48)
    /// Mauve end of the Aria avatar gradient used on the recap "Ask Aria" page.
    public static let ariaBadgeEnd = Color(red: 0.72, green: 0.45, blue: 0.58)
    /// Deep cocoa used on the "Talk with Aria" CTA label on the recap sheet.
    public static let recapCTAText = Color(red: 0.35, green: 0.25, blue: 0.22)

    // MARK: - Journey Blobs (animated background)
    public static let journeyBlobWarm = Color(red: 0.85, green: 0.55, blue: 0.52)
    public static let journeyBlobAmber = Color(red: 0.90, green: 0.72, blue: 0.55)
    public static let journeyBlobLavender = Color(red: 0.72, green: 0.60, blue: 0.78)
    public static let journeyBlobHoney = Color(red: 0.88, green: 0.68, blue: 0.40)
    /// Subtle cocoa used on dashed connector lines between cycle cards.
    public static let journeyConnectorDashed = Color(red: 0.60, green: 0.45, blue: 0.42)
    /// Richer cocoa used on solid connector lines between cycle cards.
    public static let journeyConnectorSolid = Color(red: 0.60, green: 0.42, blue: 0.38)
    /// Dark anchor dot terminating connector lines.
    public static let journeyConnectorDot = Color(red: 0.45, green: 0.33, blue: 0.28)

    // MARK: - Journey Warm Palette (milestone progress dots)
    public static let journeyPalette1 = Color(red: 0.79, green: 0.38, blue: 0.42)
    public static let journeyPalette2 = Color(red: 0.82, green: 0.45, blue: 0.40)
    public static let journeyPalette3 = Color(red: 0.84, green: 0.52, blue: 0.38)
    public static let journeyPalette4 = Color(red: 0.86, green: 0.58, blue: 0.35)
    public static let journeyPalette5 = Color(red: 0.87, green: 0.64, blue: 0.33)
    public static let journeyPalette6 = Color(red: 0.88, green: 0.70, blue: 0.32)
    public static let journeyPalette7 = Color(red: 0.85, green: 0.73, blue: 0.38)
    public static let journeyPalette8 = Color(red: 0.80, green: 0.72, blue: 0.45)
    public static let journeyPalette9 = Color(red: 0.72, green: 0.68, blue: 0.50)
    public static let journeyPalette10 = Color(red: 0.65, green: 0.62, blue: 0.55)
    public static let journeyPalette11 = Color(red: 0.60, green: 0.58, blue: 0.56)
    public static let journeyPalette12 = Color(red: 0.55, green: 0.52, blue: 0.50)
    /// Convenience array for iteration over the milestone palette.
    public static let journeyPalette: [Color] = [
        journeyPalette1, journeyPalette2, journeyPalette3, journeyPalette4,
        journeyPalette5, journeyPalette6, journeyPalette7, journeyPalette8,
        journeyPalette9, journeyPalette10, journeyPalette11, journeyPalette12,
    ]
    /// Muted pending state used behind upcoming milestone dots.
    public static let journeyPaletteMuted = Color(red: 0.55, green: 0.45, blue: 0.42)

    // MARK: - Onboarding Glow (name greeting layered glow)
    public static let onboardingGlowOuterStart = Color(hex: 0xE8D4CF)
    public static let onboardingGlowOuterEnd = Color(hex: 0xDFC4BE)
    public static let onboardingGlowInnerStart = Color(hex: 0xF5E6E2)
    public static let onboardingGlowInnerEnd = Color(hex: 0xEDD9D3)

    // MARK: - Rating Badge Tints
    public static let ratingGold = Color(red: 1.0, green: 0.84, blue: 0.0)
    public static let ratingSilver = Color(red: 0.75, green: 0.75, blue: 0.78)
    public static let ratingBronze = Color(red: 0.80, green: 0.50, blue: 0.20)

    // MARK: - Legacy/Compatibility (mapped to palette)
    public static let link = Color(hex: 0x7A5F50)  // Deep Cocoa
    public static let accentLight = Color(hex: 0xD6A59A)  // Dusty Rose
    public static let periodPink = Color(hex: 0xC8ADA7)  // Rose Taupe
    public static let periodPinkLight = Color(hex: 0xD6C5C0)  // Rose Taupe Light
    public static let progressBackground = Color(hex: 0xDECBC1)  // Warm Sandstone
}

extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
