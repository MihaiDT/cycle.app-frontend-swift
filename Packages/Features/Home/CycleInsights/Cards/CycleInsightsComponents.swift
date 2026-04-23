import ComposableArchitecture
import SwiftUI

// MARK: - Mini Visuals (shared between box previews and detail views)

extension CycleInsightsView {
    func miniBarChart(values: [Int], color: Color) -> some View {
        Canvas { context, size in
            let count = values.count
            guard count > 0 else { return }
            let maxVal = CGFloat(values.max() ?? 1)
            let gap: CGFloat = 4
            let barWidth = max((size.width - CGFloat(count - 1) * gap) / CGFloat(count), 4)
            let cr: CGFloat = barWidth * 0.3
            for (i, val) in values.enumerated() {
                let h = CGFloat(val) / maxVal * size.height * 0.82
                let x = CGFloat(i) * (barWidth + gap)
                let rect = CGRect(x: x, y: size.height - h, width: barWidth, height: h)
                let path = Path(roundedRect: rect, cornerRadius: cr)
                context.fill(path, with: .color(color.opacity(i == count - 1 ? 1 : 0.35)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func miniRing(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.85
            let lw: CGFloat = 3.5
            ZStack {
                Circle()
                    .stroke(DesignColors.structure.opacity(0.12), lineWidth: lw)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.35), color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * value)
                        ),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))%")
                    .font(.custom("Raleway-Bold", size: side * 0.25, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Cycle Length Chart

struct CycleLengthChart: View {
    let history: [CycleHistoryPoint]
    let average: Double
    var onSeeMore: (() -> Void)? = nil

    @State private var animProgress: CGFloat = 0
    @State private var selectedIndex: Int? = nil

    private let normalLow = 24
    private let normalHigh = 32

    private var values: [Int] { history.map(\.length) }
    private var maxVal: CGFloat { max(CGFloat(values.max() ?? 1) + 2, CGFloat(normalHigh) + 1) }
    private var minVal: CGFloat { min(CGFloat(values.min() ?? 1) - 2, CGFloat(normalLow) - 1) }
    private var range: CGFloat { max(maxVal - minVal, 1) }

    private func isNormal(_ length: Int) -> Bool {
        length >= normalLow && length <= normalHigh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Your cycles")
                .font(AppTypography.cardTitleSecondary)
                .tracking(AppTypography.cardTitleSecondaryTracking)
                .foregroundStyle(DesignColors.text)

            // Tooltip (when touching)
            if let idx = selectedIndex, idx < history.count {
                barTooltip(index: idx)
                    .transition(.opacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedIndex)
            }

            // Bars — proportional: 40% bar, 60% space (Headspace ratio)
            GeometryReader { geo in
                let count = values.count
                let slotW = geo.size.width / CGFloat(max(count, 1))
                let barW = min(slotW * 0.4, 32)
                let chartH = geo.size.height - 28

                HStack(spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                        let normal = isNormal(val)
                        let isSelected = selectedIndex == i
                        let barH = max((CGFloat(val) - minVal) / range * chartH * animProgress, 6)

                        VStack(spacing: 6) {
                            Spacer(minLength: 0)

                            // Value on top
                            Text("\(val)")
                                .font(.custom("Raleway-Bold", size: isSelected ? 14 : 12, relativeTo: .caption))
                                .foregroundStyle(
                                    isSelected ? DesignColors.text
                                    : (normal ? DesignColors.textSecondary : DesignColors.text.opacity(0.8))
                                )
                                .opacity(animProgress > 0.8 ? 1 : 0)

                            // Bar — thin pill
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: normal
                                            ? [DesignColors.accentSecondary.opacity(isSelected ? 0.9 : 0.5),
                                               DesignColors.accentSecondary.opacity(isSelected ? 0.5 : 0.15)]
                                            : [DesignColors.accentWarm.opacity(isSelected ? 0.9 : 0.6),
                                               DesignColors.accentWarm.opacity(isSelected ? 0.4 : 0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barW, height: barH)

                            // Month label
                            Text(monthLabel(for: history[i].startDate))
                                .font(.custom("Raleway-Medium", size: 11, relativeTo: .caption2))
                                .foregroundStyle(
                                    isSelected ? DesignColors.text : DesignColors.textPlaceholder
                                )
                        }
                        .frame(width: slotW)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selectedIndex == i {
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = i
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                }
                            }
                        }
                    }
                }
            }

            // Explore button
            if let onSeeMore {
                Button(action: onSeeMore) {
                    Text("Explore your data")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.structure.opacity(0.25))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignColors.background)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                animProgress = 1
            }
        }
    }

    // MARK: Month Label

    private func monthLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: date)
    }

    // MARK: Bar Tooltip

    private func barTooltip(index: Int) -> some View {
        let point = history[index]
        let length = values[index]
        let normal = isNormal(length)
        let diff = length - Int(average)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"

        return HStack(spacing: 12) {
            Circle()
                .fill(normal ? DesignColors.accentSecondary : DesignColors.accentWarm)
                .frame(width: 8, height: 8)

            Text("\(length) days")
                .font(.custom("Raleway-Bold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            Text("·")
                .foregroundStyle(DesignColors.textPlaceholder)

            Text("\(fmt.string(from: point.startDate))")
                .font(.custom("Raleway-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary)

            Text("·")
                .foregroundStyle(DesignColors.textPlaceholder)

            Text("\(diff >= 0 ? "+" : "")\(diff)")
                .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .caption))
                .foregroundStyle(normal ? DesignColors.accentSecondary : DesignColors.accentWarm)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignColors.structure.opacity(0.06))
        }
    }
}

// MARK: - Animated Sparkline

struct AnimatedSparkline: View {
    let values: [Int]
    let color: Color
    @State private var draw: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                SparklineFillShape(points: pts, height: geo.size.height)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(draw)

                SparklineShape(points: pts)
                    .trim(from: 0, to: draw)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = pts.last {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .position(last)
                        .opacity(draw > 0.9 ? 1 : 0)
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(last)
                        .opacity(draw > 0.9 ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) { draw = 1 }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let maxV = CGFloat(values.max() ?? 1)
        let minV = CGFloat(values.min() ?? 0)
        let range = max(maxV - minV, 1)
        let padTop: CGFloat = 8
        let padBottom: CGFloat = 18
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, val in
            let x = CGFloat(i) * step
            let y = padTop + (1 - (CGFloat(val) - minV) / range) * (size.height - padTop - padBottom)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Shapes

private struct SparklineShape: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        var p = Path()
        p.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return p
    }
}

private struct SparklineFillShape: Shape {
    let points: [CGPoint]
    let height: CGFloat
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        var p = Path()
        p.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        p.addLine(to: CGPoint(x: points.last!.x, y: height))
        p.addLine(to: CGPoint(x: points.first!.x, y: height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Cycle Stats Overview Row
//
// Twin glass boxes that sit above the Average Cycle widget on the
// Cycle Stats sheet. A quiet, editorial caption ("average cycle
// length" / "average period length") sits above the numeric value;
// the hero typography — the capitalized AVERAGE\nCYCLE title — lives
// in the widget directly below, so these two read as ground-floor
// data instead of competing for attention.
//
// Icon slots accept an asset name so the user can drop in their own
// stroke-style artwork (SVG/PNG) without this component caring about
// the shape. `renderingMode(.template)` lets the template ink pick up
// the app's warm accent on whatever material the surface resolves to.

struct StatOverviewBox: View {
    let label: String
    let iconAsset: String
    let value: String
    let hasValue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label)
                .font(AppTypography.cardLabel)
                .tracking(AppTypography.cardLabelTracking)
                .foregroundStyle(DesignColors.text.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(spacing: 10) {
                Image(iconAsset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(DesignColors.text.opacity(0.78))

                Text(value)
                    .font(.raleway(
                        hasValue ? "Bold" : "SemiBold",
                        size: hasValue ? 22 : 17,
                        relativeTo: .title3
                    ))
                    .tracking(hasValue ? -0.3 : 0)
                    .foregroundStyle(
                        hasValue
                            ? DesignColors.text
                            : DesignColors.text.opacity(0.5)
                    )
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .widgetCardStyle(cornerRadius: 22)
    }
}

struct CycleStatsOverviewRow: View {
    let cycleAverageDays: Int?
    let periodAverageDays: Int?

    var body: some View {
        HStack(spacing: 12) {
            StatOverviewBox(
                label: "Average cycle length",
                iconAsset: "icon-average-cycle",
                value: cycleAverageDays.map { "\($0) days" } ?? "No data",
                hasValue: cycleAverageDays != nil
            )

            StatOverviewBox(
                label: "Average period length",
                iconAsset: "icon-average-period",
                value: periodAverageDays.map { "\($0) days" } ?? "No data",
                hasValue: periodAverageDays != nil
            )
        }
    }
}
