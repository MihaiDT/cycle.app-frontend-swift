import Foundation
import Tagged

// MARK: - Mock Data

extension DailyCard {

    /// Returns 3 daily cards for the given cycle phase and day.
    public static func mockCards(for phase: CyclePhase, day: Int) -> [DailyCard] {
        let feel = feelCard(for: phase, day: day)
        let doCard = doCard(for: phase, day: day)
        let deeper = goDeeper(for: phase, day: day)
        return [feel, doCard, deeper]
    }

    // MARK: - FEEL cards

    private static func feelCard(for phase: CyclePhase, day: Int) -> DailyCard {
        let texts = feelTexts[phase] ?? feelTexts[.follicular]!
        let index = (day - 1) % texts.count
        let text = texts[index]

        return DailyCard(
            id: ID(rawValue: "feel-\(phase.rawValue)-\(day)"),
            cardType: .feel,
            title: text.title,
            body: text.body,
            cyclePhase: phase,
            cycleDay: day
        )
    }

    private static let feelTexts: [CyclePhase: [(title: String, body: String)]] = [
        .menstrual: [
            (
                "Rest is not quitting",
                "Your body is doing intensive work right now — shedding, rebuilding, resetting. The quieter you become, the more you can hear what it needs."
            ),
            (
                "Let it leave",
                "Old energy is leaving. What remains after the noise settles is what actually matters. You don't need to hold on to everything."
            ),
            (
                "Not lazy, recharging",
                "The women who rest here are the ones who rise strongest in their next phase. Your stillness right now is not weakness — it's strategy."
            ),
            (
                "Listen closer",
                "Your intuition is sharpest when your body is still. Pay attention to what surfaces today — it's trying to tell you something."
            ),
            (
                "The pause before growth",
                "Nothing grows without rest first. This is the necessary quiet before your next chapter begins."
            ),
        ],
        .follicular: [
            (
                "Something is waking up",
                "Follow the curiosity — it knows where to go. Your energy is climbing and your mind is sharper than it was three days ago."
            ),
            (
                "Today favors the new",
                "New ideas, new conversations, new risks. Your brain is wired for novelty right now — don't fight it with routine."
            ),
            (
                "Your creative window",
                "The ideas that come now are worth writing down. Your most creative window is opening — what you start here, you'll finish in two weeks."
            ),
            (
                "Use the momentum",
                "Your mind is sharp and your mood is lifting. This momentum is real and temporary — use it before it peaks."
            ),
            (
                "Seeds become harvests",
                "Your body is building momentum day by day. What you plant this week, you'll harvest by ovulation."
            ),
        ],
        .ovulatory: [
            (
                "You're magnetic right now",
                "People are drawn to your energy today. Your communication peaks, your confidence is real — not imagined. Use it wisely."
            ),
            (
                "Say the thing",
                "Make the ask. Take the stage. Your confidence isn't an illusion — it's estrogen and testosterone working together at their peak."
            ),
            (
                "Don't shrink",
                "The boldest version of you is the truest version right now. Don't make yourself smaller to make others comfortable."
            ),
            (
                "Words carry weight",
                "Your communication is at its peak. The words you speak today land differently — choose them with that power in mind."
            ),
            (
                "Your highest impact window",
                "Schedule the important conversation, the pitch, the date. Your body gave you a 48-hour window — this is it."
            ),
        ],
        .luteal: [
            (
                "Your inner editor is awake",
                "The things that bother you now are showing you what needs to change. This critical eye isn't negativity — it's clarity with teeth."
            ),
            (
                "You see through everything",
                "That sharp eye that appeared this week? It's not a mood swing. It's your hormones removing the filter. What you see now is real."
            ),
            (
                "Finish what you started",
                "This is your finishing phase. The project from two weeks ago? The conversation you half-had? Close the loops."
            ),
            (
                "Boundaries forming",
                "Your tolerance for nonsense drops here. That's not a flaw — it's a boundary your body is building for you."
            ),
            (
                "Discomfort is transformation",
                "The heaviness you feel is raw experience turning into wisdom. It's uncomfortable because it's working."
            ),
        ],
    ]

    // MARK: - DO cards

    private static func doCard(for phase: CyclePhase, day: Int) -> DailyCard {
        let actions = doActions[phase] ?? doActions[.follicular]!
        let index = (day - 1) % actions.count

        return actions[index]
    }

    private static let doActions: [CyclePhase: [DailyCard]] = [
        .menstrual: [
            DailyCard(
                id: ID(rawValue: "do-menstrual-breathe"),
                cardType: .do,
                title: "Slow exhale — 6 seconds",
                body: "Your nervous system is more reactive right now. Longer out-breaths activate your vagus nerve and calm the cramps.",
                cyclePhase: .menstrual,
                action: CardAction(actionType: .breathing, label: "Start · 2 min")
            ),
            DailyCard(
                id: ID(rawValue: "do-menstrual-journal"),
                cardType: .do,
                title: "What do you need today but won't ask for?",
                body: "One sentence. Don't overthink it — write the first thing that comes to mind.",
                cyclePhase: .menstrual,
                action: CardAction(actionType: .journal, label: "Write")
            ),
            DailyCard(
                id: ID(rawValue: "do-menstrual-challenge"),
                cardType: .do,
                title: "Put your phone down for 30 minutes",
                body: "Do only what your body wants. No input, no screens. Just you and whatever feels right.",
                cyclePhase: .menstrual,
                action: CardAction(actionType: .challenge, label: "I'll try this")
            ),
        ],
        .follicular: [
            DailyCard(
                id: ID(rawValue: "do-follicular-breathe"),
                cardType: .do,
                title: "Energizing breath — quick inhales",
                body: "Short, sharp inhales through the nose, long exhale through the mouth. 10 rounds. Wake your rising energy up.",
                cyclePhase: .follicular,
                action: CardAction(actionType: .breathing, label: "Start · 2 min")
            ),
            DailyCard(
                id: ID(rawValue: "do-follicular-journal"),
                cardType: .do,
                title: "What's one new thing you want to try this week?",
                body: "Your brain craves novelty in this phase. Name it — even if it's small.",
                cyclePhase: .follicular,
                action: CardAction(actionType: .journal, label: "Write")
            ),
            DailyCard(
                id: ID(rawValue: "do-follicular-challenge"),
                cardType: .do,
                title: "Say yes to the first invitation today",
                body: "Your social energy is climbing. Whatever comes first — coffee, a walk, a call — say yes before you think about it.",
                cyclePhase: .follicular,
                action: CardAction(actionType: .challenge, label: "I'll try this")
            ),
        ],
        .ovulatory: [
            DailyCard(
                id: ID(rawValue: "do-ovulatory-breathe"),
                cardType: .do,
                title: "Power breath before your big moment",
                body: "Box breathing: 4 in, 4 hold, 4 out, 4 hold. Three rounds. You're already at peak — this focuses it.",
                cyclePhase: .ovulatory,
                action: CardAction(actionType: .breathing, label: "Start · 2 min")
            ),
            DailyCard(
                id: ID(rawValue: "do-ovulatory-journal"),
                cardType: .do,
                title: "Which conversation have you been avoiding?",
                body: "You're at your most articulate and persuasive right now. Name the conversation. Then go have it.",
                cyclePhase: .ovulatory,
                action: CardAction(actionType: .journal, label: "Write")
            ),
            DailyCard(
                id: ID(rawValue: "do-ovulatory-challenge"),
                cardType: .do,
                title: "Give a real compliment to someone unexpected",
                body: "Your social radar is at its sharpest. Notice something genuine about someone you don't usually talk to — and tell them.",
                cyclePhase: .ovulatory,
                action: CardAction(actionType: .challenge, label: "I'll try this")
            ),
        ],
        .luteal: [
            DailyCard(
                id: ID(rawValue: "do-luteal-breathe"),
                cardType: .do,
                title: "Extended exhale — calm the noise",
                body: "Inhale 4 seconds, exhale 8 seconds. Your amygdala is more reactive now — this directly quiets it.",
                cyclePhase: .luteal,
                action: CardAction(actionType: .breathing, label: "Start · 3 min")
            ),
            DailyCard(
                id: ID(rawValue: "do-luteal-journal"),
                cardType: .do,
                title: "What's been irritating you for three days?",
                body: "Is it hormones or is it real? Write it down. If you still care about it on day 5 of your next cycle, it's real.",
                cyclePhase: .luteal,
                action: CardAction(actionType: .journal, label: "Write")
            ),
            DailyCard(
                id: ID(rawValue: "do-luteal-challenge"),
                cardType: .do,
                title: "Cancel one thing from your schedule today",
                body: "Something that doesn't actually matter. Your energy is finite right now — protect it for what does.",
                cyclePhase: .luteal,
                action: CardAction(actionType: .challenge, label: "I'll try this")
            ),
        ],
    ]

    // MARK: - GO DEEPER cards

    private static func goDeeper(for phase: CyclePhase, day: Int) -> DailyCard {
        let teasers = deeperTeasers[phase] ?? deeperTeasers[.follicular]!
        let index = (day - 1) % teasers.count
        let teaser = teasers[index]

        return DailyCard(
            id: ID(rawValue: "deeper-\(phase.rawValue)-\(day)"),
            cardType: .goDeeper,
            title: teaser.title,
            body: teaser.body,
            cyclePhase: phase,
            cycleDay: day,
            action: CardAction(actionType: .openLens, label: "Discover")
        )
    }

    private static let deeperTeasers: [CyclePhase: [(title: String, body: String)]] = [
        .menstrual: [
            (
                "Your body remembers what your mind forgot",
                "There's a pattern in your last three cycles that connects to something deeper than hormones..."
            ),
            (
                "The rest you resist",
                "Your chart reveals a tension between what you need and what you allow yourself to have right now..."
            ),
        ],
        .follicular: [
            (
                "This energy has a direction",
                "Your rising phase isn't random — it's pointing you toward something specific you've been circling for weeks..."
            ),
            (
                "What you start now, you'll finish differently",
                "There's a pattern in how your follicular choices play out by luteal. This cycle might break it..."
            ),
        ],
        .ovulatory: [
            (
                "Your confidence is hiding something",
                "Peak energy often masks the question you've been avoiding. Your chart suggests what it might be..."
            ),
            (
                "The thing you almost said yesterday",
                "Your communication peaks today — but there's one conversation your pattern says you keep delaying..."
            ),
        ],
        .luteal: [
            (
                "What irritates you is trying to teach you",
                "The discomfort of this phase has been consistent across your cycles. There's a message in the repetition..."
            ),
            (
                "Your clarity has a blind spot",
                "You see everything sharply right now — except one thing. Your chart points to what you're not looking at..."
            ),
        ],
    ]
}
