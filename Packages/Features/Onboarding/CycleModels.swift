import Foundation

// MARK: - Backend API Models

/// Cycle regularity options matching backend enum
public enum CycleRegularity: String, CaseIterable, Identifiable, Sendable {
    case regular = "regular"
    case somewhatRegular = "somewhat_regular"
    case irregular = "irregular"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .somewhatRegular: return "Somewhat Regular"
        case .irregular: return "Irregular"
        }
    }

    var description: String {
        switch self {
        case .regular: return "My cycle is predictable"
        case .somewhatRegular: return "Varies by a few days"
        case .irregular: return "Hard to predict"
        }
    }

    var emoji: String {
        switch self {
        case .regular: return "📅"
        case .somewhatRegular: return "📆"
        case .irregular: return "❓"
        }
    }
}

/// Symptom types matching backend enum
public enum SymptomType: String, CaseIterable, Identifiable, Sendable {
    // Physical symptoms
    case cramping = "cramping"
    case headache = "headache"
    case backPain = "back_pain"
    case bloating = "bloating"
    case breastTenderness = "breast_tenderness"
    case nausea = "nausea"
    case acne = "acne"
    case dizziness = "dizziness"
    case hotFlashes = "hot_flashes"
    case jointPain = "joint_pain"
    case allGood = "all_good"
    case fever = "fever"
    case lowBloodPressure = "low_blood_pressure"
    case vaginalDryness = "vaginal_dryness"
    case vaginalItching = "vaginal_itching"
    case vaginalPain = "vaginal_pain"

    // Digestive symptoms
    case constipation = "constipation"
    case diarrhea = "diarrhea"
    case appetiteChanges = "appetite_changes"
    case cravings = "cravings"
    case hunger = "hunger"

    // Mood & Emotional symptoms
    case calm = "calm"
    case happy = "happy"
    case sensitive = "sensitive"
    case sad = "sad"
    case apathetic = "apathetic"
    case tired = "tired"
    case angry = "angry"
    case selfCritical = "self_critical"
    case lively = "lively"
    case motivated = "motivated"
    case anxious = "anxious"
    case confident = "confident"
    case irritable = "irritable"
    case emotional = "emotional"
    case moodSwings = "mood_swings"

    // Energy & Stress
    case lowEnergy = "low_energy"
    case normalEnergy = "normal_energy"
    case highEnergy = "high_energy"
    case noStress = "no_stress"
    case manageableStress = "manageable_stress"
    case intenseStress = "intense_stress"

    // Sleep
    case peacefulSleep = "peaceful_sleep"
    case difficultyFallingAsleep = "difficulty_falling_asleep"
    case restlessSleep = "restless_sleep"
    case insomnia = "insomnia"

    // Skin
    case normalSkin = "normal_skin"
    case drySkin = "dry_skin"
    case oilySkin = "oily_skin"
    case skinBreakouts = "skin_breakouts"
    case itchySkin = "itchy_skin"

    // Hair
    case normalHair = "normal_hair"
    case shinyHair = "shiny_hair"
    case oilyHair = "oily_hair"
    case dryHair = "dry_hair"
    case sensitiveSkin = "sensitive_skin"
    case hairLoss = "hair_loss"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        // Physical
        case .cramping: return "Cramps"
        case .headache: return "Headaches"
        case .backPain: return "Back Pain"
        case .bloating: return "Bloating"
        case .breastTenderness: return "Breast Tenderness"
        case .nausea: return "Nausea"
        case .acne: return "Acne"
        case .dizziness: return "Dizziness"
        case .hotFlashes: return "Hot Flashes"
        case .jointPain: return "Joint Pain"
        case .allGood: return "All Good"
        case .fever: return "Fever"
        case .lowBloodPressure: return "Low Blood Pressure"
        case .vaginalDryness: return "Vaginal Dryness"
        case .vaginalItching: return "Vaginal Itching"
        case .vaginalPain: return "Vaginal Pain"
        // Digestive
        case .constipation: return "Constipation"
        case .diarrhea: return "Diarrhea"
        case .appetiteChanges: return "Appetite Changes"
        case .cravings: return "Cravings"
        case .hunger: return "Increased Hunger"
        // Mood
        case .calm: return "Calm"
        case .happy: return "Happy"
        case .sensitive: return "Sensitive"
        case .sad: return "Sad"
        case .apathetic: return "Apathetic"
        case .tired: return "Tired"
        case .angry: return "Angry"
        case .selfCritical: return "Self-Critical"
        case .lively: return "Lively"
        case .motivated: return "Motivated"
        case .anxious: return "Anxious"
        case .confident: return "Confident"
        case .irritable: return "Irritable"
        case .emotional: return "Emotional"
        case .moodSwings: return "Mood Swings"
        // Energy & Stress
        case .lowEnergy: return "Low Energy"
        case .normalEnergy: return "Normal Energy"
        case .highEnergy: return "High Energy"
        case .noStress: return "No Stress"
        case .manageableStress: return "Manageable"
        case .intenseStress: return "Intense Stress"
        // Sleep
        case .peacefulSleep: return "Peaceful Sleep"
        case .difficultyFallingAsleep: return "Hard to Fall Asleep"
        case .restlessSleep: return "Restless Sleep"
        case .insomnia: return "Insomnia"
        // Skin
        case .normalSkin: return "Normal Skin"
        case .drySkin: return "Dry Skin"
        case .oilySkin: return "Oily Skin"
        case .skinBreakouts: return "Breakouts"
        case .itchySkin: return "Itchy Skin"
        // Hair
        case .normalHair: return "Normal Hair"
        case .shinyHair: return "Shiny Hair"
        case .oilyHair: return "Oily Hair"
        case .dryHair: return "Dry Hair"
        case .sensitiveSkin: return "Sensitive Scalp"
        case .hairLoss: return "Hair Loss"
        }
    }

    /// Returns the custom icon name from Assets (Figma icons) or nil for SF Symbol fallback
    var customIcon: String? {
        switch self {
        // Mood - have custom Figma icons
        case .calm: return "mood_calm"
        case .happy: return "mood_happy"
        case .sensitive: return "mood_sensitive"
        case .sad: return "mood_sad"
        case .apathetic: return "mood_apathetic"
        case .tired: return "mood_tired"
        case .angry: return "mood_angry"
        case .selfCritical: return "mood_selfcritical"
        case .lively: return "mood_lively"
        case .motivated: return "mood_motivated"
        case .anxious: return "mood_anxious"
        case .confident: return "mood_confident"
        case .irritable: return "mood_irritable"
        case .emotional: return "mood_emotional"
        case .moodSwings: return "mood_swings"
        // Energy & Stress - have custom Figma icons
        case .lowEnergy: return "energy_low"
        case .normalEnergy: return "energy_normal"
        case .highEnergy: return "energy_high"
        case .noStress: return "stress_zero"
        case .manageableStress: return "stress_manageable"
        case .intenseStress: return "stress_intense"
        // Sleep - have custom Figma icons
        case .peacefulSleep: return "sleep_peaceful"
        case .difficultyFallingAsleep: return "sleep_difficulty"
        case .restlessSleep: return "sleep_restless"
        case .insomnia: return "sleep_insomnia"
        // Skin - have custom Figma icons
        case .normalSkin: return "skin_normal"
        case .drySkin: return "skin_dry"
        case .oilySkin: return "skin_oily"
        case .skinBreakouts: return "skin_acne"
        case .itchySkin: return "skin_itchy"
        // Hair - have custom Figma icons
        case .normalHair: return "hair_normal"
        case .shinyHair: return "hair_shiny"
        case .oilyHair: return "hair_oily"
        case .dryHair: return "hair_dry"
        case .sensitiveSkin: return "hair_sensitive"
        case .hairLoss: return "hair_loss"
        // Physical - have custom icons
        case .cramping: return "physical_cramps"
        case .headache: return "physical_headache"
        case .backPain: return "physical_backpain"
        case .bloating: return "physical_bloating"
        case .breastTenderness: return "physical_breast"
        case .nausea: return "physical_nausea"
        case .acne: return "physical_acne"
        case .dizziness: return "physical_dizziness"
        case .hotFlashes: return "physical_hotflash"
        case .jointPain: return "physical_joint"
        case .allGood: return "physical_allgood"
        case .fever: return "physical_fever"
        case .lowBloodPressure: return "physical_lowbloodpressure"
        case .vaginalDryness: return "physical_vaginaldryness"
        case .vaginalItching: return "physical_vaginalitching"
        case .vaginalPain: return "physical_vaginalpain"
        // Digestive - have custom icons
        case .constipation: return "digestive_constipation"
        case .diarrhea: return "digestive_diarrhea"
        case .appetiteChanges: return "digestive_appetite"
        case .cravings: return "digestive_cravings"
        case .hunger: return "digestive_hunger"
        }
    }

    /// SF Symbol fallback for symptoms without custom icons
    var sfSymbol: String {
        switch self {
        // Physical
        case .cramping: return "bandage"
        case .headache: return "brain.head.profile"
        case .backPain: return "figure.stand"
        case .bloating: return "bubble.middle.bottom"
        case .breastTenderness: return "heart"
        case .nausea: return "face.smiling.inverse"
        case .acne: return "circle.hexagonpath"
        case .dizziness: return "tornado"
        case .hotFlashes: return "thermometer.high"
        case .jointPain: return "figure.walk"
        case .allGood: return "checkmark.circle"
        case .fever: return "thermometer"
        case .lowBloodPressure: return "arrow.down.heart"
        case .vaginalDryness: return "drop"
        case .vaginalItching: return "hand.raised"
        case .vaginalPain: return "exclamationmark.circle"
        // Digestive
        case .constipation: return "arrow.down.to.line"
        case .diarrhea: return "arrow.up.to.line"
        case .appetiteChanges: return "fork.knife"
        case .cravings: return "birthday.cake"
        case .hunger: return "flame"
        // Others - fallback
        default: return "circle"
        }
    }

    /// Group symptoms by category for better UX
    static var physicalSymptoms: [SymptomType] {
        [
            .allGood, .cramping, .headache, .backPain, .bloating, .breastTenderness, .nausea, .acne, .dizziness, .hotFlashes,
            .jointPain, .fever, .lowBloodPressure, .vaginalDryness, .vaginalItching, .vaginalPain,
        ]
    }

    static var digestiveSymptoms: [SymptomType] {
        [.constipation, .diarrhea, .appetiteChanges, .cravings, .hunger]
    }

    static var moodSymptoms: [SymptomType] {
        [
            .calm, .happy, .sensitive, .sad, .apathetic, .tired, .angry, .selfCritical, .lively, .motivated, .anxious,
            .confident, .irritable, .emotional, .moodSwings,
        ]
    }

    static var energySymptoms: [SymptomType] {
        [.lowEnergy, .normalEnergy, .highEnergy, .noStress, .manageableStress, .intenseStress]
    }

    static var sleepSymptoms: [SymptomType] {
        [.peacefulSleep, .difficultyFallingAsleep, .restlessSleep, .insomnia]
    }

    static var skinSymptoms: [SymptomType] {
        [.normalSkin, .drySkin, .oilySkin, .skinBreakouts, .itchySkin]
    }

    static var hairSymptoms: [SymptomType] {
        [.normalHair, .shinyHair, .oilyHair, .dryHair, .sensitiveSkin, .hairLoss]
    }

    // Legacy groupings for backward compatibility
    static var emotionalSymptoms: [SymptomType] {
        moodSymptoms
    }
}

/// Contraception types matching backend enum
public enum ContraceptionType: String, CaseIterable, Identifiable, Sendable {
    case pill = "pill"
    case iud = "iud"
    case implant = "implant"
    case patch = "patch"
    case ring = "ring"
    case injection = "injection"
    case other = "other"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill: return "Birth Control Pill"
        case .iud: return "IUD"
        case .implant: return "Implant"
        case .patch: return "Patch"
        case .ring: return "Vaginal Ring"
        case .injection: return "Injection"
        case .other: return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .pill: return "💊"
        case .iud: return "🔷"
        case .implant: return "💉"
        case .patch: return "🩹"
        case .ring: return "⭕"
        case .injection: return "💉"
        case .other: return "➕"
        }
    }
}
