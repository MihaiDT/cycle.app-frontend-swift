import Foundation

// MARK: - Cycle Stat Info Copy
//
// Editorial copy for each stat info kind (cycle length / period length
// / variation). ACOG-accurate, cycle.app voice, present tense.
// Lives in its own file so the view code stays free of long string
// blocks and can focus on layout.

struct CycleStatInfoCopy {
    let intro: String
    let typical: String
    let typicalHighlights: [String]
    let affectIntro: String
    let affectBullets: [String]
    let affectFootnote: String?
    let doctorIntro: String
    let doctorBullets: [String]
    let doctorFootnote: String?

    static func `for`(kind: CycleStatInfoKind) -> CycleStatInfoCopy {
        switch kind {
        case .cycleLength:    return .cycleLength
        case .periodLength:   return .periodLength
        case .cycleVariation: return .cycleVariation
        }
    }
}

extension CycleStatInfoCopy {
    static let cycleLength = CycleStatInfoCopy(
        intro: "Cycle length is the span from the first day of one period to the first day of the next. It's the arc between two beginnings.",
        typical: "Adult cycles usually land between 21 and 35 days, the adult range used by the American College of Obstetricians and Gynecologists. Cycle length, period duration, and regularity together form three honest signals of hormonal and reproductive wellness.",
        typicalHighlights: [
            "In the first years after menarche, and again during perimenopause, cycles can drift wider (up to ≈ 45 days). Both are part of the map."
        ],
        affectIntro: "Cycle length is responsive. It answers to the body's bigger rhythms, and to the life around it.",
        affectBullets: [
            "Sudden shifts in training load, travel, or sleep",
            "Hormonal contraception (pills, IUDs, implants, patches)",
            "Rapid weight change or restrictive eating",
            "Chronic stress, jet lag, or shift work",
            "Endocrine conditions like thyroid issues, PCOS, or primary ovarian insufficiency",
            "Life stages like the first years after menarche, or perimenopause",
            "Genetic rhythm: some people simply run a little shorter or longer"
        ],
        affectFootnote: "Occasional variation is the body doing its job. Persistent shifts, many cycles in a row outside the typical range, are worth paying attention to.",
        doctorIntro: "A single off-pattern cycle isn't a flag. A sustained pattern is.",
        doctorBullets: [
            "Cycles frequently shorter than 21 or longer than 35 days",
            "A regular rhythm suddenly turning erratic",
            "Periods that pause for more than 90 days (outside pregnancy)",
            "Bleeding between periods, or after sex",
            "Severe pain that disrupts daily life",
            "Bleeding heavy enough to soak through protection every hour"
        ],
        doctorFootnote: nil
    )

    static let periodLength = CycleStatInfoCopy(
        intro: "Period length is the total span of bleeding within a single cycle, from the first drop to the last.",
        typical: "A typical period runs between 2 and 7 days (ACOG). Alongside cycle length and regularity, bleed duration is one of the clearest day-to-day signals of reproductive wellness.",
        typicalHighlights: [
            "In adolescence, especially the first year or two after menarche, bleeds can reach 7 to 9 days while hormones find their pattern. Usually expected, rarely a concern."
        ],
        affectIntro: "A number of things can stretch a bleed, shorten it, or swing it month to month.",
        affectBullets: [
            "Genetic and hormonal baseline, plus your current life stage",
            "Hormonal contraception",
            "Lifestyle shifts like stress, travel, or new medication",
            "Changes in weight, training, or nutritional status",
            "Adolescence or perimenopause",
            "Underlying conditions like fibroids, polyps, adenomyosis, PCOS, thyroid disorders, or bleeding disorders",
            "Short-term disruption from illness, vaccination, or missed logs"
        ],
        affectFootnote: "Occasional variation reads as noise. Bleeds frequently under 2 days, or stretching past 7 to 9, deserve a closer look.",
        doctorIntro: "Small shifts in duration are common. These are worth naming to a provider:",
        doctorBullets: [
            "Bleeding longer than 7 days",
            "Soaking through protection every hour for several hours running",
            "Using two products at once to manage flow",
            "Needing to change protection overnight",
            "Passing clots larger than about 2.5 cm",
            "Feeling faint, weak, breathless, or chest discomfort during or after your period"
        ],
        doctorFootnote: "Heavy menstrual bleeding, even inside a normal cycle length, can affect quality of life and lead to iron-deficiency anemia over time."
    )

    static let cycleVariation = CycleStatInfoCopy(
        intro: "Variation measures how much your cycle length changes from month to month. It's the difference between a steady rhythm and one that fluctuates.",
        typical: "Some month-to-month drift is expected. Cycles shifting by a few days at a time fit within normal hormonal rhythm; the body is responding to stress, travel, sleep, and illness.",
        typicalHighlights: [
            "We calculate variation as the standard deviation across your logged cycles. It appears once you've tracked at least 3 full cycles."
        ],
        affectIntro: "The same forces that shape an individual cycle also shape the variation between cycles.",
        affectBullets: [
            "Big life changes like a new job, a big move, or caregiving load",
            "Starting or changing hormonal contraception",
            "Training load or weight swings",
            "Sleep debt or extended jet lag",
            "Thyroid, PCOS, or other endocrine shifts",
            "Perimenopause, when variation often widens before cycles stop entirely"
        ],
        affectFootnote: "A short burst of uneven cycles during a hard month is common. A long stretch of wide swings is what's worth watching.",
        doctorIntro: "Reach out if variation stays wide or suddenly expands:",
        doctorBullets: [
            "A previously steady rhythm turning inconsistent",
            "Cycles swinging by more than a week between back-to-back months",
            "Variation paired with heavy bleeding, severe pain, or missed periods",
            "Cycles shorter than 21 or longer than 35 days repeating"
        ],
        doctorFootnote: nil
    )
}
