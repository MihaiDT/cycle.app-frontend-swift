import SwiftUI

/// Domain model for the symptom logging sheet.
///
/// Owns the category → symptoms mapping plus the visual tokens
/// (icon, tint, background gradient) that drive each tab's
/// appearance. Lives in `Models/` because it's pure data, not a
/// view — every consumer (tab bar, page grid, summary pill) reads
/// from the same source.
enum SymptomCategory: String, CaseIterable {
    case smart = "For you"
    case physical = "Physical"
    case mood = "Mood"
    case energy = "Energy"
    case sleep = "Sleep"
    case digestive = "Digestive"
    case skin = "Skin & Hair"

    var icon: String {
        switch self {
        case .smart: "lightbulb"
        case .physical: "figure.run"
        case .mood: "face.smiling"
        case .energy: "bolt.circle"
        case .sleep: "moon.zzz"
        case .digestive: "fork.knife"
        case .skin: "hands.and.sparkles.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .smart: DesignColors.accentWarm
        case .physical: DesignColors.accentWarm
        case .mood: DesignColors.roseTaupe
        case .energy: DesignColors.accentSecondary
        case .sleep: DesignColors.textCard
        case .digestive: DesignColors.structure
        case .skin: DesignColors.accent
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .smart: [DesignColors.background, DesignColors.accentWarm.opacity(0.10)]
        case .physical: [DesignColors.background, DesignColors.accent.opacity(0.08)]
        case .mood: [DesignColors.background, DesignColors.roseTaupeLight.opacity(0.12)]
        case .energy: [DesignColors.background, DesignColors.accentSecondary.opacity(0.06)]
        case .sleep: [DesignColors.background, DesignColors.textCard.opacity(0.06)]
        case .digestive: [DesignColors.background, DesignColors.structure.opacity(0.08)]
        case .skin: [DesignColors.background, DesignColors.accent.opacity(0.1)]
        }
    }

    /// Static symptom list per category. The `.smart` case
    /// returns an empty array because its content is dynamic
    /// — driven by `SmartSymptomProvider` from the user's
    /// current cycle phase. The View resolves the actual list
    /// at render time, falling back to this property for every
    /// other category.
    var symptoms: [SymptomType] {
        switch self {
        case .smart:
            []
        case .physical:
            [
                .cramping, .headache, .backPain, .bloating, .breastTenderness, .nausea,
                .acne, .dizziness, .hotFlashes, .jointPain, .allGood, .fever,
            ]
        case .mood:
            [
                .calm, .happy, .sensitive, .sad, .apathetic, .tired, .angry,
                .lively, .motivated, .anxious, .confident, .irritable, .emotional, .moodSwings,
            ]
        case .energy:
            [.lowEnergy, .normalEnergy, .highEnergy, .noStress, .manageableStress, .intenseStress]
        case .sleep:
            [.peacefulSleep, .difficultyFallingAsleep, .restlessSleep, .insomnia]
        case .digestive:
            [.constipation, .diarrhea, .appetiteChanges, .cravings, .hunger]
        case .skin:
            [
                .normalSkin, .drySkin, .oilySkin, .skinBreakouts, .itchySkin,
                .normalHair, .shinyHair, .oilyHair, .dryHair, .hairLoss,
            ]
        }
    }
}
