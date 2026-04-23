import SwiftUI

// MARK: - Cycle Stat Info Detail
//
// Full-screen explainer opened from the Normality card's info buttons.
// Three variants (cycle length / period length / variation) share one
// layout — editorial title block, a recap card pinned next to a hero
// image slot, then a quiet flow of sections: "What's typical", "What
// can shift it", "When to check in". Copy is cycle.app's own voice —
// warm, present-tense, ACOG-accurate, never diagnostic.

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
                headerBlock
                recapBlock
                normalSection
                affectSection
                doctorSection
                disclaimer
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { JourneyAnimatedBackground(animated: false) }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.eyebrow.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(DesignColors.text.opacity(0.75))

            Text(kind.title)
                .font(AppTypography.cardTitlePrimary)
                .tracking(AppTypography.cardTitlePrimaryTracking)
                .foregroundStyle(DesignColors.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.intro)
                .font(.raleway("Regular", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
                .padding(.top, 4)
        }
    }

    // MARK: - Recap + Hero

    @ViewBuilder
    private var recapBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(kind.recapLabel)
                    .font(.raleway("Medium", size: 12, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.85))

                Text(previousValue ?? "No data")
                    .font(.raleway(
                        previousValue != nil ? "Bold" : "SemiBold",
                        size: previousValue != nil ? 26 : 17,
                        relativeTo: .title2
                    ))
                    .tracking(-0.4)
                    .foregroundStyle(
                        previousValue != nil
                            ? DesignColors.text
                            : DesignColors.text.opacity(0.45)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let badge {
                    CycleStatusBadgeView(badge: badge)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetCardStyle(cornerRadius: 22)

            heroImageSlot
                .frame(width: 124, height: 156)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var normalSection: some View {
        sectionBlock(
            title: "What's typical",
            body: copy.typical,
            highlights: copy.typicalHighlights,
            image: .inline(asset: copy.inlineImageAsset, height: 168)
        )
    }

    @ViewBuilder
    private var affectSection: some View {
        sectionBlock(
            title: "What can shift it",
            body: copy.affectIntro,
            bullets: copy.affectBullets,
            image: nil,
            footnote: copy.affectFootnote
        )
    }

    @ViewBuilder
    private var doctorSection: some View {
        sectionBlock(
            title: "When to check in with a provider",
            body: copy.doctorIntro,
            bullets: copy.doctorBullets,
            image: .banner(asset: copy.bannerImageAsset, height: 140),
            footnote: copy.doctorFootnote
        )
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

    private enum InlineImage {
        case inline(asset: String, height: CGFloat)
        case banner(asset: String, height: CGFloat)
    }

    @ViewBuilder
    private func sectionBlock(
        title: String,
        body: String,
        highlights: [String] = [],
        bullets: [String] = [],
        image: InlineImage? = nil,
        footnote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.raleway("Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)

            Text(body)
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(highlights, id: \.self) { line in
                Text(line)
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(bullets, id: \.self) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(DesignColors.accentWarm.opacity(0.7))
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(line)
                                .font(.raleway("Regular", size: 15, relativeTo: .body))
                                .foregroundStyle(DesignColors.text.opacity(0.82))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }

            if let footnote {
                Text(footnote)
                    .font(.raleway("Medium", size: 14, relativeTo: .callout))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            if let image {
                switch image {
                case let .inline(asset, height):
                    inlineImageSlot(asset: asset, height: height)
                        .padding(.top, 6)
                case let .banner(asset, height):
                    inlineImageSlot(asset: asset, height: height)
                        .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - Image Slots

    @ViewBuilder
    private var heroImageSlot: some View {
        imageSlot(asset: kind.heroAsset, aspect: .portrait)
    }

    @ViewBuilder
    private func inlineImageSlot(asset: String, height: CGFloat) -> some View {
        imageSlot(asset: asset, aspect: .fixed(height: height))
    }

    fileprivate enum SlotAspect {
        case portrait
        case fixed(height: CGFloat)
    }

    @ViewBuilder
    private func imageSlot(asset: String, aspect: SlotAspect) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let image = UIImage(named: asset)

        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        DesignColors.accentWarm.opacity(0.16),
                        DesignColors.accentSecondary.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(DesignColors.text.opacity(0.55))
                    Text(asset)
                        .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                        .tracking(0.4)
                        .foregroundStyle(DesignColors.text.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                }
            }
        }
        .modifier(SlotFrameModifier(aspect: aspect))
        .clipShape(shape)
        .overlay {
            shape
                .stroke(DesignColors.accentWarm.opacity(0.22), lineWidth: 0.8)
        }
    }

}

// MARK: - Slot frame modifier

private struct SlotFrameModifier: ViewModifier {
    let aspect: CycleStatInfoDetailView.SlotAspect

    func body(content: Content) -> some View {
        switch aspect {
        case .portrait:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .fixed(height):
            content
                .frame(maxWidth: .infinity)
                .frame(height: height)
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
    let inlineImageAsset: String
    let bannerImageAsset: String

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
        doctorFootnote: nil,
        inlineImageAsset: "stat-info-cycle-length-normal",
        bannerImageAsset: "stat-info-cycle-length-provider"
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
        doctorFootnote: "Heavy menstrual bleeding, even inside a normal cycle length, can affect quality of life and lead to iron-deficiency anemia over time.",
        inlineImageAsset: "stat-info-period-length-normal",
        bannerImageAsset: "stat-info-period-length-provider"
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
        doctorFootnote: nil,
        inlineImageAsset: "stat-info-cycle-variation-normal",
        bannerImageAsset: "stat-info-cycle-variation-provider"
    )
}
