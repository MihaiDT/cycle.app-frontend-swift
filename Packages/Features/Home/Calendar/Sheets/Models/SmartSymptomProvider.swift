import Foundation

/// Resolves the symptom list shown in the **For you** tab of
/// the symptom logging sheet.
///
/// The For-you tab surfaces symptoms most likely to be relevant
/// for the user's current hormonal phase — so the first thing
/// she sees is a small, focused grid for *now*, not the full
/// 56-symptom catalogue.
///
/// ## How the list is composed
///
/// 1. **Confirmed patterns** for the current phase (from
///    `PatternDetector` via `MenstrualLocalClient.detectPatterns`)
///    take priority — if the user has a confirmed luteal-phase
///    headache pattern, headache shows up first in the For-you
///    grid when she's in the luteal phase. Patterns are her own
///    body's signal, ranked above any clinical default.
/// 2. **Phase defaults** below fill the rest, de-duplicated
///    against pattern hits so the same symptom never appears
///    twice in the grid.
///
/// ## Source for the phase defaults
///
/// Each phase list is drawn from clinically standard symptom
/// patterns documented by:
///   * **ACOG** (American College of Obstetricians and
///     Gynecologists) — Premenstrual Syndrome (PMS),
///     Dysmenorrhea, Abnormal Uterine Bleeding patient FAQs
///   * **NHS** — Periods, PMS pages
///   * **Mayo Clinic** — Menstrual cycle: What's normal,
///     PMS, Premenstrual Dysphoric Disorder
///
/// The lists are small on purpose (6–10 symptoms per phase) —
/// the goal is "right now this is most likely", not "every
/// symptom that could occur in this window".
struct SmartSymptomProvider {
    let phase: CyclePhase?
    let confirmedPatterns: [PatternDetector.RawPatternSignal]

    init(
        phase: CyclePhase?,
        confirmedPatterns: [PatternDetector.RawPatternSignal] = []
    ) {
        self.phase = phase
        self.confirmedPatterns = confirmedPatterns
    }

    var symptoms: [SymptomType] {
        var result: [SymptomType] = []
        var seen = Set<String>()

        // 1. User-confirmed patterns for THIS phase, ordered by
        // occurrence count desc — strongest signal first.
        let phaseRaw = phase?.rawValue
        let myPatterns = confirmedPatterns
            .filter { !$0.isEmerging && $0.phase.rawValue == phaseRaw }
            .sorted { $0.occurrences > $1.occurrences }

        for signal in myPatterns {
            guard let symptom = SymptomType(rawValue: signal.symptomTypeRaw),
                  seen.insert(signal.symptomTypeRaw).inserted else { continue }
            result.append(symptom)
        }

        // 2. Phase defaults, skipping any symptom already
        // included from the user's own patterns.
        for symptom in Self.phaseDefaults(for: phase) {
            guard seen.insert(symptom.rawValue).inserted else { continue }
            result.append(symptom)
        }

        return result
    }

    // MARK: - Phase defaults

    /// Phase-specific lists. Symptom names map 1:1 to
    /// `SymptomType` cases. Order follows clinical relevance —
    /// the most-cited symptom for each phase comes first.
    private static func phaseDefaults(for phase: CyclePhase?) -> [SymptomType] {
        switch phase {
        case .menstrual:
            // Day 1–5: estrogen + progesterone at floor.
            // Prostaglandin-driven cramping is universal;
            // estrogen-withdrawal headache is the second
            // most reported. Iron loss + hormonal nadir →
            // fatigue + low mood.
            return [
                .cramping,
                .lowEnergy,
                .headache,
                .moodSwings,
                .bloating,
                .breastTenderness,
                .backPain,
                .tired,
                .sad,
            ]

        case .follicular:
            // Day ~6–13: rising estrogen. Energy and mood
            // climb, sleep stabilises, cognitive clarity
            // peaks. The "good week" most users describe.
            return [
                .highEnergy,
                .happy,
                .motivated,
                .calm,
                .lively,
                .peacefulSleep,
                .normalEnergy,
                .confident,
                .normalSkin,
            ]

        case .ovulatory:
            // Day ~14–16: peak estrogen + LH surge. Energy
            // and libido peak; ~20% of users feel mid-cycle
            // pain (mittelschmerz). Breast tenderness onset,
            // heightened sensitivity.
            return [
                .highEnergy,
                .lively,
                .happy,
                .breastTenderness,
                .sensitive,
                .cramping,
                .cravings,
                .skinBreakouts,
            ]

        case .luteal, .late:
            // Day 17–28: rising then falling progesterone,
            // dropping estrogen. PMS territory — bloating,
            // mood swings, irritability, anxiety, cyclical
            // mastalgia, breakouts, cravings.
            return [
                .bloating,
                .moodSwings,
                .anxious,
                .irritable,
                .breastTenderness,
                .acne,
                .cravings,
                .tired,
                .lowEnergy,
                .cramping,
                .headache,
                .sad,
            ]

        case .none:
            // No cycle data yet — show a neutral starter
            // set spanning common everyday symptoms across
            // all phases. Less a "smart" pick, more a
            // "here's what people log most often" fallback.
            return [
                .normalEnergy,
                .happy,
                .calm,
                .cramping,
                .headache,
                .bloating,
                .lowEnergy,
                .moodSwings,
            ]
        }
    }
}
