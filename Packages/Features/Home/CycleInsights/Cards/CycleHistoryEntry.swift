import SwiftUI


// MARK: - Entry

struct CycleHistoryEntry: View {
    let timeline: CycleHistoryTimeline
    /// Fired when the user taps the ellipsis menu. The parent card
    /// owns the sheet presentation state — keeping it out of here
    /// avoids the ForEach/fullScreenCover edge cases that silently
    /// cancel inline sheet presentations.
    let onMenuTap: () -> Void

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            entryHeader
            CycleHistoryBar(timeline: timeline)
            CycleHistoryDayScale(length: timeline.length)
            CycleHistoryDotRows(timeline: timeline)
        }
    }

    @ViewBuilder
    private var entryHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
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
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(periodSubLabel)
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.85))

                    Button(action: onMenuTap) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CycleHistoryPressableButtonStyle())
                    .accessibilityLabel("Hide this cycle")

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                }
            }
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

    private static let barHeight: CGFloat = 10
    private static let fertileOvulationMarkerSize: CGFloat = 6

    // Canvas replaces a `GeometryReader` + `ZStack` of Capsules +
    // Circles. Each entry previously had 4+ SwiftUI views just for
    // the bar, and 4 visible entries meant 16 views per card row;
    // Canvas draws everything in a single GPU pass so the card
    // materializes much faster inside a UICollectionView cell.
    var body: some View {
        Canvas { ctx, size in
            let length = max(timeline.length, 1)
            let dayWidth = size.width / CGFloat(length)
            let periodWidth = dayWidth * CGFloat(min(timeline.bleedingDays, timeline.length))
            let fertileX = dayWidth * CGFloat(timeline.fertileWindow.lowerBound - 1)
            let fertileWidth = dayWidth * CGFloat(timeline.fertileWindow.count)
            let ovulationCenter = dayWidth * (CGFloat(timeline.ovulationDay) - 0.5)
            let radius = Self.barHeight / 2

            // Background capsule
            let bgRect = CGRect(x: 0, y: 0, width: size.width, height: Self.barHeight)
            ctx.fill(
                Path(roundedRect: bgRect, cornerRadius: radius),
                with: .color(DesignColors.text.opacity(0.06))
            )

            // Fertile window capsule
            if fertileWidth > 0 {
                let fertileRect = CGRect(x: fertileX, y: 0, width: fertileWidth, height: Self.barHeight)
                ctx.fill(
                    Path(roundedRect: fertileRect, cornerRadius: radius),
                    with: .color(CyclePhase.ovulatory.orbitColor.opacity(0.55))
                )
            }

            // Period capsule
            if periodWidth > 0 {
                let periodRect = CGRect(x: 0, y: 0, width: periodWidth, height: Self.barHeight)
                ctx.fill(
                    Path(roundedRect: periodRect, cornerRadius: radius),
                    with: .color(CyclePhase.menstrual.orbitColor.opacity(0.95))
                )
            }

            // Ovulation marker — inner dot with ring
            let markerSize = Self.fertileOvulationMarkerSize
            let innerRect = CGRect(
                x: ovulationCenter - markerSize / 2,
                y: Self.barHeight / 2 - markerSize / 2,
                width: markerSize,
                height: markerSize
            )
            ctx.fill(Path(ellipseIn: innerRect), with: .color(DesignColors.background))
            ctx.stroke(
                Path(ellipseIn: innerRect),
                with: .color(CyclePhase.ovulatory.orbitColor),
                lineWidth: 1.4
            )
        }
        .frame(height: Self.barHeight)
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
            switch self {
            case .energy: return DesignColors.accentWarmText
            case .mood:   return DesignColors.roseTaupe
            case .sleep:  return DesignColors.text.opacity(0.65)
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
