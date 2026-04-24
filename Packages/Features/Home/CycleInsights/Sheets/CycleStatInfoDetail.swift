import SwiftUI

// MARK: - Cycle Stat Info Detail
//
// Full-screen explainer opened from the Normality card's info buttons.
// Three variants (cycle length / period length / variation) share one
// editorial layout:
//   - hero block (eyebrow · title · lead paragraph)
//   - user's recent value with its clinical badge
//   - typical-range chip pulled from ACOG windows
//   - three sign-posted sections ("What's typical", "What can shift
//     it", "When to check in with a provider")
//   - quiet disclaimer
// Copy is the same cycle.app voice (ACOG-accurate, present tense, not
// diagnostic) — the redesign is purely in the visual + accessibility
// language.

struct CycleStatInfoDetailView: View {
    let kind: CycleStatInfoKind
    let previousValue: String?
    let badge: CycleStatusBadge?

    private let copy: CycleStatInfoCopy

    init(
        kind: CycleStatInfoKind,
        previousValue: String?,
        badge: CycleStatusBadge?
    ) {
        self.kind = kind
        self.previousValue = previousValue
        self.badge = badge
        self.copy = CycleStatInfoCopy.for(kind: kind)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                hero
                recapCard
                typicalRangeChip
                sectionDivider
                typicalSection
                affectSection
                doctorSection
                disclaimer
            }
            .padding(.horizontal, AppLayout.screenHorizontal + 8)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignColors.background.ignoresSafeArea())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind.eyebrow.uppercased())
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)

            Text(kind.title)
                .font(AppTypography.cardTitlePrimary)
                .tracking(AppTypography.cardTitlePrimaryTracking)
                .foregroundStyle(DesignColors.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(copy.intro)
                .font(.raleway("Regular", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Recap card

    @ViewBuilder
    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(kind.recapLabel)
                    .font(AppTypography.cardLabel)
                    .tracking(AppTypography.cardLabelTracking)
                    .foregroundStyle(DesignColors.textSecondary)
                Spacer(minLength: 8)
                if let badge {
                    CycleStatusBadgeView(badge: badge)
                }
            }

            Text(previousValue ?? "No data yet")
                .font(.raleway("Bold", size: previousValue != nil ? 34 : 22, relativeTo: .largeTitle))
                .tracking(-0.6)
                .foregroundStyle(
                    previousValue != nil
                        ? DesignColors.text
                        : DesignColors.text.opacity(0.45)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recapAccessibilityLabel)
    }

    private var recapAccessibilityLabel: String {
        let value = previousValue ?? "No data"
        let badgeSuffix = badge.map { ", \($0.label.lowercased())" } ?? ""
        return "\(kind.recapLabel), \(value)\(badgeSuffix)"
    }

    // MARK: - Typical range chip

    @ViewBuilder
    private var typicalRangeChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignColors.accentWarm)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Typical range")
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
                Text(kind.typicalRangeLabel)
                    .font(.raleway("SemiBold", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
            }

            Spacer(minLength: 0)

            Text(kind.typicalSourceLabel)
                .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                .tracking(0.3)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.accentWarm.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignColors.accentWarm.opacity(0.18), lineWidth: 0.6)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Typical range: \(kind.typicalRangeLabel), \(kind.typicalSourceLabel)")
    }

    // MARK: - Sections

    @ViewBuilder
    private var typicalSection: some View {
        sectionBlock(
            icon: "checkmark.seal",
            title: "What's typical",
            body: copy.typical,
            highlights: copy.typicalHighlights
        )
    }

    @ViewBuilder
    private var affectSection: some View {
        sectionBlock(
            icon: "wind",
            title: "What can shift it",
            body: copy.affectIntro,
            bullets: copy.affectBullets,
            footnote: copy.affectFootnote
        )
    }

    @ViewBuilder
    private var doctorSection: some View {
        sectionBlock(
            icon: "stethoscope",
            title: "When to check in with a provider",
            body: copy.doctorIntro,
            bullets: copy.doctorBullets,
            footnote: copy.doctorFootnote
        )
    }

    @ViewBuilder
    private var sectionDivider: some View {
        Rectangle()
            .fill(DesignColors.text.opacity(0.08))
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var disclaimer: some View {
        Text("cycle.app is not a diagnostic tool and does not provide medical advice. Everything you read here is for educational context only. For personal concerns, please speak with a licensed healthcare professional.")
            .font(.raleway("Medium", size: 12, relativeTo: .caption))
            .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    // MARK: - Section builder

    @ViewBuilder
    private func sectionBlock(
        icon: String,
        title: String,
        body: String,
        highlights: [String] = [],
        bullets: [String] = [],
        footnote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle().fill(DesignColors.accentWarm.opacity(0.10))
                    }
                    .accessibilityHidden(true)

                Text(title)
                    .font(AppTypography.cardTitleSecondary)
                    .tracking(AppTypography.cardTitleSecondaryTracking)
                    .foregroundStyle(DesignColors.text)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(body)
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(highlights, id: \.self) { line in
                        highlightBlock(line)
                    }
                }
            }

            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(bullets, id: \.self) { line in
                        bulletRow(line)
                    }
                }
                .accessibilityElement(children: .contain)
            }

            if let footnote {
                Text(footnote)
                    .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func highlightBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(DesignColors.accentWarm.opacity(0.45))
                .frame(width: 2.5)
                .accessibilityHidden(true)

            Text(text)
                .font(.raleway("Medium", size: 14, relativeTo: .callout))
                .foregroundStyle(DesignColors.text)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 2)
    }

    @ViewBuilder
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(DesignColors.accentWarm)
                .frame(width: 5, height: 5)
                .padding(.top, 9)
                .accessibilityHidden(true)

            Text(text)
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Kind — Typical range

extension CycleStatInfoKind {
    var typicalRangeLabel: String {
        switch self {
        case .cycleLength:    return "21–35 days"
        case .periodLength:   return "2–7 days"
        case .cycleVariation: return "Up to a few days month to month"
        }
    }

    var typicalSourceLabel: String {
        switch self {
        case .cycleLength, .periodLength: return "ACOG"
        case .cycleVariation:             return "Clinical norm"
        }
    }
}

// MARK: - Copy (editorial, ACOG-accurate)

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
