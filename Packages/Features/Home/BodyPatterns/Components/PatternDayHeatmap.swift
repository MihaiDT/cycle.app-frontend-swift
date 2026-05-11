import SwiftUI

// MARK: - Pattern Day Heatmap
//
// Cycle × cycle-day heatmap for the Pattern Detail hero. Each
// **column** is one cycle (newest on the left), each **row** is a
// cycle day. Filled circle = day the symptom was logged that
// cycle, tint intensity keyed by severity. Empty days render as a
// faint outline ring.
//
// Layout idiom:
//   * Day labels (Day 1, Day 2…) sit in a fixed left gutter so
//     they stay visible while the user scrolls cycles in / out.
//   * Cycle columns live in a horizontal `ScrollView` so any
//     number of cycles can be browsed by swiping right — the
//     viewport shows the most recent ones up front, older cycles
//     overflow off the screen edge and scroll into view.
//
// Why this beats severity-as-bar-height:
//   * Most users default-log at severity 3 every time. A
//     severity-keyed bar chart goes flat the moment they have a
//     steady pattern. The heatmap shows *where in the cycle* the
//     symptom hits — that varies naturally even when severity is
//     uniform.
//
// `targetColumnCount` controls the chart's "minimum width" so
// patterns with 1–2 cycles still render the same canvas as ones
// with 3+ — short patterns pad with placeholder columns instead
// of shrinking.

struct PatternDayHeatmap: View {
    let dayLogs: [PatternDayLog]
    let phase: CyclePhase
    /// Stable id of the cycle to highlight as "current". Pass nil
    /// to skip the column highlight.
    let highlightedCycleStart: Date?
    /// How many cycle columns to render at minimum. Patterns with
    /// fewer cycles pad with placeholder columns so the chart's
    /// footprint stays the same as the user's data grows. Defaults
    /// to 3 — matches the screen's default cycle window.
    var targetColumnCount: Int = 3
    /// How many cycle columns are currently visible. Caller animates
    /// this value via `withAnimation` to drive the cascade — rather
    /// than `.transition(...)` modifiers with `.delay(...)`, which
    /// queue unreliably across rapid toggles. Columns at index ≥
    /// this value scale to zero and fade out in place.
    var visibleColumnCount: Int = .max
    /// Same contract as `visibleColumnCount` for the day rows.
    /// Caller animates separately so column-cascade and day-cascade
    /// can run in parallel with their own stagger.
    var visibleDayCount: Int = .max
    /// When false, the symptom-icon watermark is hidden. Caller
    /// flips this to `false` on the expanded view so the cascade of
    /// new columns / days isn't crowded by the trailing glyph.
    var showsWatermark: Bool = true
    /// Raw `SymptomType` value used to render a watermark glyph
    /// inside the trailing ambient bloom — the same artwork used by
    /// `PatternWidgetCard`'s ghost icon, scaled up and offset off
    /// the screen so it reads as a faint signature behind the data.
    /// Pass nil to skip the watermark.
    var symptomTypeRaw: String? = nil
    /// Cycle day to prioritise in the column ordering. Cycles where
    /// this day has a log show first (left), so the collapsed
    /// preview demonstrates the insight quoted in the parent's
    /// `HITS HARDEST` tile rather than burying it past the chevron
    /// toggle. Pass nil to keep strict chronological order.
    var priorityDay: Int? = nil

    private var matchedSymptomType: SymptomType? {
        symptomTypeRaw.flatMap { SymptomType(rawValue: $0) }
    }

    private var palette: BodyPatternsPalette {
        BodyPatternsPalette.forPhase(phase)
    }

    static let cellSize: CGFloat = 38
    static let cellSpacing: CGFloat = 8
    static let columnSpacing: CGFloat = 10
    static let dayLabelWidth: CGFloat = 64
    static let monthLabelHeight: CGFloat = 22
    /// Horizontal gap between the day-labels gutter and the cycle
    /// columns scrollview. Slightly wider than `columnSpacing` so
    /// the labels don't crowd the first column.
    static let gutterToColumnsSpacing: CGFloat = 14

    /// Cycles present in the logs. Default order is newest first.
    /// When `priorityDay` is set, cycles where that day has a log
    /// are surfaced first (still newest-first within that group),
    /// then the rest in newest-first. The collapsed preview reads
    /// the leftmost N — surfacing priority cycles there means the
    /// preview demonstrates the parent's insight rather than
    /// hiding it behind a Show more.
    private var cycles: [Date] {
        let unique = Set(dayLogs.map(\.cycleStartDate))
        let chronological = Array(unique).sorted(by: >)

        guard let priorityDay else { return chronological }

        let priorityCycleStarts = Set(
            dayLogs
                .filter { $0.cycleDay == priorityDay }
                .map { $0.cycleStartDate }
        )
        let withPriority = chronological.filter { priorityCycleStarts.contains($0) }
        let withoutPriority = chronological.filter { !priorityCycleStarts.contains($0) }
        return withPriority + withoutPriority
    }

    /// Cycle days that earn a row in the heatmap, reactive to the
    /// current visible-cycle window.
    ///
    /// Two filters compose:
    ///   1. Frequency — days with logs in ≥ 2 cycles globally
    ///      ("the pattern's spine"; one-off days are grid noise).
    ///   2. Visibility — of those, only days that actually have
    ///      a log in the cycles currently rendered. Days whose
    ///      evidence sits past the show-more cutoff are hidden in
    ///      collapsed view, then reappear on expand as their
    ///      cycles enter the window. No empty rows promising
    ///      data the user can't see yet.
    ///
    /// When no qualifying day surfaces in the visible window
    /// (e.g. early cycles before the pattern hardens) we fall
    /// back to global frequent days, then to every logged day,
    /// so the chart is never empty.
    private var visibleDays: [Int] {
        guard !dayLogs.isEmpty else { return [1, 2] }

        // Frequency threshold across all data.
        let dayCycleCounts: [Int: Set<Date>] = dayLogs.reduce(into: [:]) { acc, log in
            acc[log.cycleDay, default: []].insert(log.cycleStartDate)
        }
        let frequentDays = dayCycleCounts
            .filter { $0.value.count >= 2 }
            .keys

        // Cycles that are actually rendering right now (prefix
        // of the priority-sorted list, capped by visible /
        // target column count).
        let renderColumnCount = min(
            max(visibleColumnCount, targetColumnCount),
            cycles.count
        )
        let visibleCycleSet = Set(cycles.prefix(renderColumnCount))
        let daysInVisibleCycles = Set(
            dayLogs
                .filter { visibleCycleSet.contains($0.cycleStartDate) }
                .map(\.cycleDay)
        )

        let surfaced = frequentDays
            .filter { daysInVisibleCycles.contains($0) }
            .sorted()
        if !surfaced.isEmpty { return surfaced }

        // Fallback 1: no frequent day appears in the visible
        // window. Surface global frequent days so the chart still
        // has shape (only happens during cascade transitions or
        // for tiny histories).
        let globalFrequent = Array(frequentDays).sorted()
        if !globalFrequent.isEmpty { return globalFrequent }

        // Fallback 2: nothing meets the threshold at all. Show
        // every logged day so the user sees their data.
        let everyLogged = Set(dayLogs.map(\.cycleDay)).sorted()
        if everyLogged.count < 2, let only = everyLogged.first {
            return [only, only + 1]
        }
        return everyLogged
    }

    /// Subset of `visibleDays` that renders right now — paginated by
    /// `visibleDayCount`. Caller animates the count with stepped
    /// `withAnimation` so each row transitions in its own
    /// transaction.
    private var visibleDaysSubset: [Int] {
        let count = min(visibleDayCount, visibleDays.count)
        return Array(visibleDays.prefix(count))
    }

    var body: some View {
        HStack(alignment: .top, spacing: PatternDayHeatmap.gutterToColumnsSpacing) {
            dayGutter
            cycleColumns
        }
        .background(alignment: .trailing) {
            ambientBloom
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Cycle columns inside a horizontal ScrollView. Always
    /// scrollable so the layout stays consistent regardless of
    /// cycle count: 3 cycles cluster leading with empty trailing
    /// (filled by the bloom + watermark), 12 cycles scroll right
    /// off the screen edge. Trailing fade mask softens the
    /// right edge so content reads as "more beyond" instead of
    /// jamming at the edge of the viewport.
    private var cycleColumns: some View {
        // Render up to `visibleColumnCount` cycles + any
        // placeholders needed to reach `targetColumnCount` in the
        // compact preview. The caller animates `visibleColumnCount`
        // via scheduled `withAnimation` blocks (one per column step)
        // so each column's insertion/removal fires in its own
        // animation transaction — no `.delay()` on the transition,
        // no queue conflicts across rapid toggles.
        let totalAvailable = max(targetColumnCount, cycles.count)
        let renderCount = min(max(targetColumnCount, visibleColumnCount), totalAvailable)
        let indices = Array(0..<renderCount)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: PatternDayHeatmap.columnSpacing) {
                ForEach(indices, id: \.self) { index in
                    Group {
                        if index < cycles.count {
                            column(for: cycles[index])
                        } else {
                            placeholderColumn
                        }
                    }
                    .transition(
                        .scale(scale: 0.5, anchor: .topLeading)
                            .combined(with: .opacity)
                    )
                }
            }
            .padding(.trailing, 20)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.96),
                    .init(color: .black.opacity(0), location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Ambient bloom

    /// Phase-tinted radial bloom anchored to the trailing edge of
    /// the heatmap, plus an optional symptom watermark. Two stacked
    /// radials give a controlled glow; the watermark glyph reads
    /// as a faint signature behind the data, tinted very low so it
    /// doesn't compete with the cells. Hidden in expanded view so
    /// the new columns / days cascade onto a clean canvas.
    private var ambientBloom: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.40))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 150, y: 30)

            Circle()
                .fill(palette.glow)
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 100, y: 0)

            if showsWatermark, let symptom = matchedSymptomType {
                symptomIcon(for: symptom, size: 200)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(x: 120, y: 10)
                    // Asymmetric timing so the icon doesn't fight
                    // the cascade. On collapse (icon returning),
                    // wait ~280ms for the column cascade to clear
                    // the trailing area, then fade in. On expand
                    // (icon leaving), ease out gently — slight
                    // scale-down + 0.5s easeOut — so it dissolves
                    // into the columns sliding into its space
                    // rather than popping off.
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 1.05))
                                .animation(.easeOut(duration: 0.32).delay(0.28)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.92, anchor: .center))
                                .animation(.easeOut(duration: 0.5))
                        )
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Day gutter (fixed left column)

    /// Fixed left gutter — only the per-day labels. The previous
    /// "CYCLE DAY" caps caption above them read as a foreign chrome
    /// element (eyebrow vocabulary in a place that's already
    /// self-evident), so it's dropped. The phantom spacer at the
    /// top keeps the rows vertically aligned with the cycle-month
    /// labels at the top of each column.
    private var dayGutter: some View {
        VStack(alignment: .trailing, spacing: PatternDayHeatmap.cellSpacing) {
            Color.clear
                .frame(height: PatternDayHeatmap.monthLabelHeight)

            ForEach(visibleDaysSubset, id: \.self) { day in
                Text("Day \(day)")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .subheadline))
                    .tracking(-0.2)
                    .foregroundStyle(DesignColors.text.opacity(0.78))
                    .lineLimit(1)
                    .frame(height: PatternDayHeatmap.cellSize, alignment: .center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: PatternDayHeatmap.dayLabelWidth, alignment: .trailing)
    }

    // MARK: - Cycle column

    @ViewBuilder
    private func column(for cycle: Date) -> some View {
        let isHighlighted = (cycle == highlightedCycleStart)
        let logsByDay: [Int: PatternDayLog] = Dictionary(
            dayLogs
                .filter { $0.cycleStartDate == cycle }
                .map { ($0.cycleDay, $0) },
            uniquingKeysWith: { existing, candidate in
                candidate.severity > existing.severity ? candidate : existing
            }
        )

        VStack(spacing: PatternDayHeatmap.cellSpacing) {
            Text(monthLabel(for: cycle))
                .font(.raleway(isHighlighted ? "Bold" : "Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(isHighlighted ? DesignColors.text : DesignColors.textSecondary)
                .frame(height: PatternDayHeatmap.monthLabelHeight)

            ForEach(visibleDaysSubset, id: \.self) { day in
                cell(log: logsByDay[day], day: day)
                    .transition(
                        .scale(scale: 0.55, anchor: .topLeading)
                            .combined(with: .opacity)
                    )
            }
        }
        // No frame on the latest cycle — smart preview already
        // tells the story by sorting priority cycles to the left;
        // an extra frame around the latest column drew the eye to
        // a column with mostly empty cells and competed with the
        // pattern row that smart preview surfaced. Bold month
        // label keeps a quiet "this is the most recent" cue.
    }

    // MARK: - Placeholder column

    /// Empty column rendered when the pattern has fewer cycles than
    /// `targetColumnCount`. Em-dash month label, outlined cells at
    /// very low opacity. Hidden from VoiceOver — shouldn't surface
    /// as content.
    private var placeholderColumn: some View {
        VStack(spacing: PatternDayHeatmap.cellSpacing) {
            Text("—")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.30))
                .frame(height: PatternDayHeatmap.monthLabelHeight)

            ForEach(visibleDaysSubset, id: \.self) { _ in
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .strokeBorder(DesignColors.text.opacity(0.10), lineWidth: 0.8)
                    }
                    .frame(width: PatternDayHeatmap.cellSize, height: PatternDayHeatmap.cellSize)
                    .opacity(0.55)
                    .transition(.scale(scale: 0.55, anchor: .topLeading).combined(with: .opacity))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(log: PatternDayLog?, day: Int) -> some View {
        if let log {
            Circle()
                .fill(palette.accent.opacity(opacityFor(severity: log.severity)))
                .overlay {
                    Circle()
                        .strokeBorder(palette.accent.opacity(0.45), lineWidth: 0.6)
                }
                .frame(width: PatternDayHeatmap.cellSize, height: PatternDayHeatmap.cellSize)
                .accessibilityLabel("Day \(day), severity \(String(format: "%.1f", log.severity)) of 5")
        } else {
            // Empty cell — soft glass fill + hairline stroke. The
            // 1pt outline-only treatment was too faint against the
            // peach background; an `.ultraThinMaterial` fill plus a
            // thin cocoa stroke makes the empty slot read as a
            // physical socket instead of an absence.
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .strokeBorder(DesignColors.text.opacity(0.16), lineWidth: 0.8)
                }
                .shadow(color: DesignColors.text.opacity(0.04), radius: 1, x: 0, y: 0.5)
                .frame(width: PatternDayHeatmap.cellSize, height: PatternDayHeatmap.cellSize)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Helpers

    private func opacityFor(severity: Double) -> Double {
        let normalized = max(0.0, min(1.0, (severity - 1.0) / 4.0))
        return 0.30 + normalized * 0.70
    }

    private func monthLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    private var accessibilityLabel: String {
        guard !dayLogs.isEmpty else { return "No log data yet." }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let perCycle = cycles.map { cycle -> String in
            let days = dayLogs
                .filter { $0.cycleStartDate == cycle }
                .map(\.cycleDay)
                .sorted()
                .map(String.init)
                .joined(separator: ", ")
            return "\(formatter.string(from: cycle)): days \(days)"
        }
        return "Days logged per cycle: " + perCycle.joined(separator: "; ") + "."
    }
}
