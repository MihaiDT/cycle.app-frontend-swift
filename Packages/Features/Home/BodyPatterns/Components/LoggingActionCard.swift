import SwiftUI

// MARK: - Logging Action Card
//
// Single hero card at the top of `BodyPatternsView` — replaces
// the previous pair (`TodayCheckInCard` + `RecentLogsSection`).
// The two used to live as separate blocks at opposite ends of
// the screen, but they served the same job ("see / extend my
// recent logging activity"), used the same data origin
// (`recentLogs`), and shared the same color story. Splitting
// them across the surface read as duplicate scaffolding.
//
// This component fuses the CTA empty-state and the recent-logs
// populated-state into one `widgetCardStyle` shell. The header
// row (eyebrow + title + circular `+` button) is invariant —
// the `+` never moves regardless of state, so the user's eye
// always knows where the "add a log" affordance is. The body
// below the header morphs between two branches via a spring
// transition so the chips appear to grow from the same corner
// the `+` lives in:
//
//   • Empty:     "Log a symptom or mood – even one is enough."
//   • Populated: horizontal scroll of warm capsule chips,
//                ranked by occurrence count, capped at eight.
//
// Tapping the `+` opens the symptom log sheet on today.
// Tapping a chip opens the symptom log sheet on the day that
// symptom was last logged, pre-anchored to its category tab.

struct LoggingActionCard: View {
    let recentLogs: [RecentSymptomEntry]
    var hiddenSymptomRaws: Set<String> = []
    let onLogTapped: () -> Void
    var onChipTap: (Date, SymptomType) -> Void = { _, _ in }

    private var todayEyebrow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: Date()).uppercased()
        return "TODAY · \(weekday)"
    }

    private var rankedItems: [RankedItem] {
        Self.rankedSymptoms(
            from: recentLogs,
            excluding: hiddenSymptomRaws
        )
    }

    private var hasLogs: Bool { !rankedItems.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            bodyContent
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `interactive: false` — the card itself isn't a tap
        // target (only the `+` orb and chip buttons are). Leaving
        // iOS 26's interactive glass shader on would race the
        // inner buttons for hit-testing and ate occasional taps,
        // surfaced as "I had to tap twice for it to work" plus
        // `IOSurfaceClientSetSurfaceNotify failed` console noise.
        .widgetCardStyle(cornerRadius: 28, interactive: false)
        // Drives the morph between empty copy and chip strip
        // when the first log lands or the array clears. Same
        // app-wide spring profile used by DailyCheckIn /
        // MoodArc per `Packages/Core/DesignSystem/CLAUDE.md`.
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: hasLogs)
    }

    // MARK: - Header row (always visible)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(todayEyebrow)
                    .font(.raleway("Bold", size: 11, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.accentWarm)

                Text("How are you feeling?")
                    .font(.raleway("SemiBold", size: 18, relativeTo: .title3))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignColors.text,
                                DesignColors.textPrincipal,
                                DesignColors.text.opacity(0.85),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            addButton
        }
    }

    /// 56pt warm orb with a soft halo, specular top highlight,
    /// stratified drop shadow, and a slightly heavier plus
    /// glyph. Reads as a hand-crafted affordance instead of a
    /// default `+ in a circle` chip — light catches the top
    /// curve, the halo bleeds warmth into the surrounding card,
    /// and the press style gives a measured spring bounce
    /// (scale 0.9 + opacity dip) instead of a flat tap.
    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.75)
            onLogTapped()
        } label: {
            ZStack {
                // Main warm gradient orb.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignColors.accentWarm,
                                DesignColors.accentSecondary,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    // Specular top arc — soft light hitting
                    // the upper curve. Stronger near the top,
                    // fades to nothing at the bottom; soft-light
                    // blend keeps it subtle on the warm fill.
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.0),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                            .blendMode(.softLight)
                    }
                    // Single soft drop shadow — subtle warm
                    // grounding, no second layer. The previous
                    // double-shadow + halo combo overshot and
                    // made the button look like it was floating
                    // off the card.
                    .shadow(
                        color: DesignColors.accentWarm.opacity(0.18),
                        radius: 6,
                        x: 0,
                        y: 3
                    )

                // Plus glyph — heavier weight so it reads as
                // engraved into the orb, not stuck on top.
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(LoggingAddButtonPressStyle())
        .accessibilityLabel("Log a symptom for today")
        .accessibilityHint("Opens the symptom log on today")
    }

    // MARK: - Body content (state-dependent)

    @ViewBuilder
    private var bodyContent: some View {
        if hasLogs {
            chipStrip
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .scale(scale: 0.88, anchor: .topTrailing)),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.95, anchor: .topTrailing))
                    )
                )
        } else {
            emptyCopy
                .transition(.opacity)
        }
    }

    /// Empty-state body — single line of muted copy that names
    /// the action. En-dash per the cycle.app copy rule.
    private var emptyCopy: some View {
        Text("Log a symptom or mood – even one is enough.")
            .font(.raleway("Medium", size: 13, relativeTo: .footnote))
            .foregroundStyle(DesignColors.textSecondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Populated body — horizontal chip strip

    /// Horizontal scroll of warm capsule chips. The strip bleeds
    /// past the card's leading inset so chips can glide off the
    /// edge as the user scrolls — same idiom as the pattern
    /// carousel above and the previous `RecentLogsSection`.
    private var chipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(rankedItems, id: \.symptom.rawValue) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onChipTap(item.mostRecentDate, item.symptom)
                    } label: {
                        chip(for: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(item.symptom.displayName), open the day it was logged"
                    )
                }
            }
            // Inner gutter so the first chip starts flush with
            // the card's content column even when the row
            // ScrollView extends past it via the negative
            // outer padding below.
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        // Bleed past the card's 20pt content padding so chips
        // can slide off the trailing edge of the card during
        // horizontal scroll, instead of jamming at the inset.
        .padding(.horizontal, -20)
    }

    private func chip(for item: RankedItem) -> some View {
        HStack(spacing: 8) {
            symptomIcon(for: item.symptom, size: 15)
                .foregroundStyle(DesignColors.accentWarm)

            Text(item.symptom.displayName)
                .font(.raleway("SemiBold", size: 14, relativeTo: .footnote))
                .foregroundStyle(DesignColors.text.opacity(0.88))

            Text("· \(Self.relativeStamp(for: item.mostRecentDate))")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.text.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(DesignColors.accent.opacity(0.22))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.22),
                            lineWidth: 0.6
                        )
                )
                .shadow(color: DesignColors.accentWarm.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Ranking + relative stamp

    /// One row in the chip strip — the symptom plus the
    /// freshest date it was logged on. Rendering uses
    /// `symptom`; tapping routes to `mostRecentDate` so the
    /// log sheet opens on the day the user actually logged it.
    struct RankedItem {
        let symptom: SymptomType
        let mostRecentDate: Date
        let count: Int
    }

    /// Group entries by symptom, capture the freshest log per
    /// group, sort by occurrence count desc → recency desc →
    /// raw value asc. Capped at eight; the strip is a glance,
    /// not an inventory. Without the tie-breakers, Swift's
    /// Dictionary sort returns chips in non-deterministic
    /// order across re-renders, which made the strip "shift"
    /// every time the patterns carousel scrolled.
    static func rankedSymptoms(
        from logs: [RecentSymptomEntry],
        excluding hiddenSymptomRaws: Set<String>
    ) -> [RankedItem] {
        var counts: [String: Int] = [:]
        var latest: [String: Date] = [:]
        for entry in logs where !hiddenSymptomRaws.contains(entry.symptomTypeRaw) {
            counts[entry.symptomTypeRaw, default: 0] += 1
            if let prior = latest[entry.symptomTypeRaw] {
                latest[entry.symptomTypeRaw] = max(prior, entry.date)
            } else {
                latest[entry.symptomTypeRaw] = entry.date
            }
        }
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                if let l = latest[lhs.key], let r = latest[rhs.key], l != r {
                    return l > r
                }
                return lhs.key < rhs.key
            }
            .prefix(8)
            .compactMap { (raw, count) -> RankedItem? in
                guard let symptom = SymptomType(rawValue: raw),
                      let date = latest[raw] else { return nil }
                return RankedItem(
                    symptom: symptom,
                    mostRecentDate: date,
                    count: count
                )
            }
    }

    /// Natural-language relative timestamp rendered inline on
    /// each chip — readable without abbreviation, compact past
    /// a week so the chip never outgrows its row.
    private static func relativeStamp(for date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2..<7: return "\(days) days ago"
        case 7..<14: return "1 week ago"
        case 14..<30: return "\(days / 7) weeks ago"
        default: return "\(days / 30) months ago"
        }
    }
}

// MARK: - Press style
//
// Custom bounce for the warm orb. Default `.plain` style gives
// a flat tap; this one scales down to 0.9, dims slightly, and
// springs back so the orb feels physical — like a polished
// pebble being pressed into the surface and released. Matches
// the app-wide spring profile (response 0.32, damping 0.78).

private struct LoggingAddButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                .spring(response: 0.32, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}
