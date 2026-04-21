import Foundation

// MARK: - Cycle Live Engine
//
// Maps the woman's current phase + the category of her Your moment tile
// into an editorial "why this makes sense today" snippet for the Journey
// Cycle Live widget.
//
// Resolution order:
//   1. (phase, category) — specific framing
//   2. phase only — generic phase framing as fallback
//
// The category keys mirror ChallengeTemplate.category strings
// ("self_care", "mindfulness", "movement", "creative", "nutrition",
// "social"). If a future category is added and not mapped here, we
// fall back to the phase-only copy.

public enum CycleLiveEngine {
    public static func content(
        phase: CyclePhase,
        cycleDay: Int?,
        momentCategory: String?
    ) -> CycleLiveContent {
        let normalized = momentCategory?.lowercased()

        if let category = normalized,
           let specific = pairedCopy(phase: phase, category: category) {
            return CycleLiveContent(
                phase: phase,
                cycleDay: cycleDay,
                category: category,
                title: specific.title,
                body: specific.body
            )
        }

        let generic = phaseCopy(phase: phase)
        return CycleLiveContent(
            phase: phase,
            cycleDay: cycleDay,
            category: normalized,
            title: generic.title,
            body: generic.body
        )
    }

    // MARK: Paired (phase × category) copy

    private static func pairedCopy(
        phase: CyclePhase,
        category: String
    ) -> (title: String, body: String)? {
        switch (phase, category) {

        // Menstrual
        case (.menstrual, "self_care"):
            return ("A softer pace", "Your body is shedding and rebuilding. Rest is the work today.")
        case (.menstrual, "mindfulness"):
            return ("Quiet inside", "Less noise, less stimulation. A few slow breaths go further now.")
        case (.menstrual, "movement"):
            return ("Gentle motion", "Stretching or a walk is enough. Save intensity for later this week.")
        case (.menstrual, "creative"):
            return ("A reflective day", "Your attention turns inward. Journaling or making something quiet fits.")
        case (.menstrual, "nutrition"):
            return ("Warm and mineral-rich", "Iron, warmth, and hydration help you recover faster.")
        case (.menstrual, "social"):
            return ("Close circle only", "One trusted person, low-key. Big crowds can wait a few days.")

        // Follicular
        case (.follicular, "self_care"):
            return ("Energy returning", "Your body is waking up. Small rituals now set the tone for the whole cycle.")
        case (.follicular, "mindfulness"):
            return ("Clear-headed", "Your focus sharpens this week. A short sit helps you choose what matters.")
        case (.follicular, "movement"):
            return ("Ready to move", "Strength and stamina climb. This is a good day to challenge yourself.")
        case (.follicular, "creative"):
            return ("New ideas surface", "Curiosity is high. Start something — you'll have the energy to finish.")
        case (.follicular, "nutrition"):
            return ("Fresh and light", "Lean protein and colorful plates match the energy building inside.")
        case (.follicular, "social"):
            return ("Outward again", "Conversations flow easier this week. A good time to reach out.")

        // Ovulatory
        case (.ovulatory, "self_care"):
            return ("Your peak window", "Confidence runs high. Treat yourself — this version of you deserves it.")
        case (.ovulatory, "mindfulness"):
            return ("Present and open", "You're most here this week. A mindful pause keeps you from running past it.")
        case (.ovulatory, "movement"):
            return ("Peak strength", "Your body is most capable now. A harder workout lands perfectly.")
        case (.ovulatory, "creative"):
            return ("Your voice is loudest", "Ship what you've been sitting on. Expression comes easier today.")
        case (.ovulatory, "nutrition"):
            return ("Fuel the fire", "Your metabolism is running hot. Eat enough to match the output.")
        case (.ovulatory, "social"):
            return ("Magnetic week", "People are drawn to you now. Make the call, send the invite.")

        // Luteal
        case (.luteal, "self_care"):
            return ("Turn inward", "Your body is asking for softness. A ritual now prevents tomorrow's edge.")
        case (.luteal, "mindfulness"):
            return ("The inner editor", "Your critic sharpens this week. Breath work helps you use it without being used by it.")
        case (.luteal, "movement"):
            return ("Steady, not sharp", "Keep it moderate. Yoga or walking beats a hard session right now.")
        case (.luteal, "creative"):
            return ("Refining, not starting", "This is the week to finish, edit, organize. Don't start something huge.")
        case (.luteal, "nutrition"):
            return ("Stable blood sugar", "Complex carbs and magnesium help smooth the descent into your period.")
        case (.luteal, "social"):
            return ("Smaller, deeper", "Big groups drain you this week. One close friend refills you.")

        default:
            return nil
        }
    }

    // MARK: Phase-only fallback

    private static func phaseCopy(
        phase: CyclePhase
    ) -> (title: String, body: String) {
        switch phase {
        case .menstrual:
            return (
                "A week of rest",
                "Your body is shedding and rebuilding. Less input, more recovery."
            )
        case .follicular:
            return (
                "Energy is returning",
                "Estrogen climbs this week. Focus, curiosity, and stamina come back online."
            )
        case .ovulatory:
            return (
                "Your peak window",
                "You're at your most magnetic, strongest, and clearest. Use it."
            )
        case .luteal:
            return (
                "Turning inward",
                "Progesterone rises and your attention shifts. Finish, refine, slow the pace."
            )
        case .late:
            return (
                "On your own timeline",
                "Your body is taking its time. Steady rhythms help more than urgency."
            )
        }
    }
}
