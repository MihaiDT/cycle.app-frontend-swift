import SwiftUI


// MARK: - Entry

struct CycleHistoryEntry: View, Equatable {
    let timeline: CycleHistoryTimeline
    /// Fired when the user taps the ellipsis menu. The parent card
    /// owns the sheet presentation state — keeping it out of here
    /// avoids the ForEach/fullScreenCover edge cases that silently
    /// cancel inline sheet presentations.
    let onMenuTap: () -> Void

    /// Equatable lets the parent card wrap each entry with
    /// `.equatable()`, so the per-entry body (which renders ~30
    /// period dots + 3 reading dot rows = 100+ subviews) doesn't
    /// re-evaluate when the underlying timeline is unchanged. The
    /// closure is intentionally excluded — it dispatches into the
    /// parent card's stable sheet binding.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.timeline == rhs.timeline
    }

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            entryHeader
            CycleHistoryBar(timeline: timeline)
            // Energy / Mood / Sleep dots only for cycles with at least
            // one daily check-in. Empty rows on untracked cycles read
            // as "you forgot to log" (guilt pattern) when the real
            // story is usually just "this cycle happened before daily
            // check-ins existed".
            if !timeline.reports.isEmpty {
                CycleHistoryDotRows(timeline: timeline)
            }
        }
    }

    /// Header collapsed to a single row (May 2026): duration +
    /// date range + CURRENT badge + eye-slash hide button +
    /// chevron drill-in. Removed the legacy second row that
    /// repeated `Period: N days` — that information lives on
    /// the detail screen one tap away. The eye-slash stays
    /// visible inline so the hide-cycle utility is still
    /// discoverable without long-press.
    @ViewBuilder
    private var entryHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if timeline.isCurrent {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("Day")
                        .font(.raleway("Medium", size: 12, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                    Text("\(headerNumber)")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(headerNumber)")
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundStyle(DesignColors.text)
                    Text(headerNumber == 1 ? "day" : "days")
                        .font(.raleway("Medium", size: 12, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }

            Text("·")
                .font(.raleway("Medium", size: 12, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.6))

            Text(dateRangeLabel)
                .font(.raleway("Medium", size: 12, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)

            if timeline.isCurrent {
                Text("CURRENT")
                    .font(.raleway("SemiBold", size: 9, relativeTo: .caption2))
                    .tracking(1.0)
                    .foregroundStyle(DesignColors.text)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(DesignColors.text.opacity(0.08))
                    }
            }

            Spacer(minLength: 4)

            Button(action: onMenuTap) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CycleHistoryPressableButtonStyle())
            .accessibilityLabel("Hide this cycle")

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
        }
    }

    /// For completed cycles: total length ("28 days"). For the
    /// in-progress cycle: the day number you're living in today,
    /// so a day-1 cycle reads "Day 1 · from Apr 22" instead of the
    /// projected-length fiction.
    private var headerNumber: Int {
        if timeline.isCurrent {
            let cal = Calendar.current
            let days = cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: timeline.startDate),
                to: cal.startOfDay(for: Date())
            ).day ?? 0
            return max(1, days + 1)
        }
        return timeline.length
    }

    private var headerNounLabel: String {
        if timeline.isCurrent {
            return headerNumber == 1 ? "day in" : "days in"
        }
        return timeline.length == 1 ? "day" : "days"
    }

    private var dateRangeLabel: String {
        let start = Self.rangeFormatter.string(from: timeline.startDate)
        if timeline.isCurrent {
            return "from \(start)"
        }
        let end = Self.rangeFormatter.string(from: timeline.endDate)
        return "\(start) – \(end)"
    }

    private var periodSubLabel: String {
        let bleed = timeline.bleedingDays
        let noun = bleed == 1 ? "day" : "days"
        return "Period: \(bleed) \(noun)"
    }
}

// MARK: - Bar

struct CycleHistoryBar: View {
    let timeline: CycleHistoryTimeline

    private static let dotSize: CGFloat = 8
    private static let barHeight: CGFloat = 12

    /// One dot per day, drawn in a single `Canvas` pass instead of a
    /// `ForEach` of `PhaseGlossyDot` views. The original implementation
    /// instantiated ~30 SwiftUI views per bar (each `PhaseGlossyDot` is
    /// a tinted gradient + specular sheen overlay = multiple internal
    /// nodes) — for a 3-cycle history card that meant ~270+ view-graph
    /// nodes laid out and re-evaluated on every body invocation. Canvas
    /// draws the whole row in one GPU pass with zero view-graph cost,
    /// matching the optimization already in place on `CycleHistoryDotRows`.
    var body: some View {
        Canvas { ctx, size in
            let length = max(timeline.length, 1)
            let slotWidth = size.width / CGFloat(length)
            let midY = size.height / 2
            let radius = Self.dotSize / 2

            for day in 1...length {
                let cx = slotWidth * (CGFloat(day) - 0.5)
                let rect = CGRect(
                    x: cx - radius,
                    y: midY - radius,
                    width: Self.dotSize,
                    height: Self.dotSize
                )
                let path = Path(ellipseIn: rect)

                switch dayRole(day) {
                case .period:
                    ctx.fill(path, with: .color(CyclePhase.menstrual.orbitColor.opacity(0.95)))
                case .fertile:
                    ctx.fill(path, with: .color(CyclePhase.ovulatory.orbitColor.opacity(0.55)))
                case .ovulation:
                    ctx.fill(path, with: .color(DesignColors.background))
                    ctx.stroke(path, with: .color(CyclePhase.ovulatory.orbitColor), lineWidth: 1.4)
                case .neutral:
                    ctx.fill(path, with: .color(DesignColors.text.opacity(0.10)))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.barHeight)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    private enum DayRole { case period, fertile, ovulation, neutral }

    private func dayRole(_ day: Int) -> DayRole {
        if day == timeline.ovulationDay { return .ovulation }
        if day <= timeline.bleedingDays { return .period }
        if timeline.fertileWindow.contains(day) { return .fertile }
        return .neutral
    }

    private var accessibilityLabel: String {
        "\(timeline.length) day cycle, \(timeline.bleedingDays) period days, ovulation on day \(timeline.ovulationDay)"
    }
}

// MARK: - Bar Legend
//
// Quiet legend row beneath the per-day dot bar. Without this, the
// rose / amber / outlined-circle vocabulary reads as decorative —
// "pretty colors I can't decode" — which is the AI-slop trap. A
// single subtle row of swatches + labels turns the bar into a
// readable artifact: each dot earns its meaning at a glance.

struct CycleHistoryBarLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            swatch(
                label: "Period",
                tint: CyclePhase.menstrual.orbitColor,
                fillOpacity: 0.95
            )
            swatch(
                label: "Fertile",
                tint: CyclePhase.ovulatory.orbitColor,
                fillOpacity: 0.55
            )
            ringSwatch(
                label: "Ovulation",
                tint: CyclePhase.ovulatory.orbitColor
            )
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func swatch(label: String, tint: Color, fillOpacity: Double) -> some View {
        HStack(spacing: 6) {
            PhaseGlossyDot(tint: tint, tintOpacity: fillOpacity)
            Text(label)
                .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                .tracking(0.4)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
    }

    private func ringSwatch(label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .stroke(tint, lineWidth: 1.2)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                .tracking(0.4)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
    }
}

// MARK: - Day Scale

struct CycleHistoryDayScale: View {
    let length: Int

    /// Step chosen so the scale lists ~8-13 markers regardless of
    /// cycle length — short cycles (21d) show every 2 days, long
    /// ones (45d) jump to every 4, keeping the number row visually
    /// even across the card.
    private var step: Int {
        switch length {
        case ...24:  return 2
        case 25...35: return 3
        default:     return 4
        }
    }

    private var markers: [Int] {
        var arr: [Int] = []
        var day = 1
        while day <= length {
            arr.append(day)
            day += step
        }
        if arr.last != length { arr.append(length) }
        return arr
    }

    var body: some View {
        // Canvas draws the day numbers in one pass — previously each
        // marker was a SwiftUI `Text` inside `ForEach`, which meant
        // ~8–13 view nodes per entry × 4 entries per card. Canvas's
        // `.draw(Text, at:)` API resolves the `Text` once and renders
        // it inline.
        Canvas { ctx, size in
            let dayWidth = size.width / CGFloat(max(length, 1))
            let midY = size.height / 2
            for day in markers {
                let x = dayWidth * (CGFloat(day) - 0.5)
                let text = Text("\(day)")
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.75))
                ctx.draw(text, at: CGPoint(x: x, y: midY), anchor: .center)
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Dot Rows

struct CycleHistoryDotRows: View {
    let timeline: CycleHistoryTimeline

    private enum Metric: CaseIterable {
        case energy, mood, sleep

        var label: String {
            switch self {
            case .energy: return "Energy"
            case .mood:   return "Mood"
            case .sleep:  return "Sleep"
            }
        }

        var tint: Color {
            // Pulled from the app palette so the rows stay on-brand
            // (no foreign reds/greens), but spaced far enough across
            // hue + lightness that they don't blur into a single
            // warm-earth gradient at the 5pt dot size.
            //   Energy → honey gold (warm/yellow, "sun")
            //   Mood   → dusty rose (pink, distinct from gold)
            //   Sleep  → cocoa dark (deep, "night")
            switch self {
            case .energy: return DesignColors.accentHoneyText
            case .mood:   return DesignColors.accentSecondary
            case .sleep:  return DesignColors.text
            }
        }

        func value(in report: JourneyReportInput) -> Int {
            switch self {
            case .energy: return report.energy
            case .mood:   return report.mood
            case .sleep:  return report.sleep
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(Metric.allCases), id: \.self) { metric in
                row(for: metric)
            }
        }
    }

    @ViewBuilder
    private func row(for metric: Metric) -> some View {
        HStack(spacing: 10) {
            // Canvas replaces a `GeometryReader` + `ForEach(1...length)`
            // of individual `Circle` views — for a 30-day cycle that
            // was ~60 SwiftUI views per row, ~180 per entry, ~720 per
            // fully-populated history card. Canvas draws the whole row
            // in a single GPU pass with zero view-graph cost.
            Canvas { ctx, size in
                let length = max(timeline.length, 1)
                let dayWidth = size.width / CGFloat(length)
                let midY = size.height / 2
                let filledColor = metric.tint
                let emptyStrokeColor = DesignColors.text.opacity(0.18)

                for day in 1...length {
                    let x = dayWidth * (CGFloat(day) - 0.5)
                    if let report = timeline.reports[day], metric.value(in: report) > 0 {
                        let clamped = max(1, min(5, metric.value(in: report)))
                        let alpha = 0.35 + 0.65 * (Double(clamped - 1) / 4.0)
                        let rect = CGRect(x: x - 2.5, y: midY - 2.5, width: 5, height: 5)
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .color(filledColor.opacity(alpha))
                        )
                    } else {
                        let rect = CGRect(x: x - 2, y: midY - 2, width: 4, height: 4)
                        ctx.stroke(
                            Path(ellipseIn: rect),
                            with: .color(emptyStrokeColor),
                            lineWidth: 0.6
                        )
                    }
                }
            }
            .frame(height: 10)

            Text(metric.label)
                .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.9))
                .frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - Pressable Button Style
//
// Tactile press feedback matching `PressableButtonStyle` on the
// Average Cycle card — scale + dim briefly while held so the
