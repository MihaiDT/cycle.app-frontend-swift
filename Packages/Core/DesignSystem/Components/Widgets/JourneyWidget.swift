import SwiftUI

// MARK: - Journey Widget
//
// Hero widget for the Home widget carousel's "Journey" slide. Mirrors the
// `WellnessWidget` shape exactly (padding, corners, meta row, detail
// chevron) so the two feel like a matched pair as the user swipes
// between them. Content: the number of cycles tracked so far + a mini
// mandala visualizing them. No "unlock" framing — just a calm snapshot
// of the user's journey so far.

public struct JourneyWidget: View {
    public let cycleCount: Int
    public let currentCycleNumber: Int
    public let currentCycleDay: Int?
    public let onDetailTap: (() -> Void)?

    public init(
        cycleCount: Int,
        currentCycleNumber: Int,
        currentCycleDay: Int? = nil,
        onDetailTap: (() -> Void)? = nil
    ) {
        self.cycleCount = cycleCount
        self.currentCycleNumber = currentCycleNumber
        self.currentCycleDay = currentCycleDay
        self.onDetailTap = onDetailTap
    }

    // MARK: - Derived copy

    private var heroNumber: String { "\(cycleCount)" }

    private var heroSubtitle: String {
        if cycleCount == 0 { return "this is cycle one" }
        if cycleCount == 1 { return "cycle tracked" }
        return "cycles tracked"
    }

    private var metaText: String {
        if let day = currentCycleDay {
            return "CYCLE \(currentCycleNumber) · DAY \(day)"
        }
        return "CYCLE \(currentCycleNumber)"
    }

    /// Mandala dot count scales with tracked cycles but caps at 12 so
    /// the visual stays balanced. Once the user crosses 12 cycles, the
    /// dots reset into "year two" mode (visualisation of the latest 12).
    private var mandalaDotCount: Int {
        min(max(cycleCount, 3), 12)
    }

    private var isCurrentCyclePartial: Bool {
        // The current cycle is rendered as a "current" dot in the
        // mandala while it's still in progress.
        cycleCount < 12
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { onDetailTap?() }) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(metaText)
                        .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                        .tracking(0.6)
                        .foregroundStyle(DesignColors.textSecondary)
                        .padding(.bottom, 12)

                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(heroNumber)
                                .font(.raleway("Black", size: 44, relativeTo: .title))
                                .tracking(-1.2)
                                .foregroundStyle(DesignColors.text)
                                .contentTransition(.numericText())
                            Text(heroSubtitle)
                                .font(.raleway("Bold", size: 14, relativeTo: .subheadline))
                                .foregroundStyle(DesignColors.accentWarmText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        mandala
                            .frame(width: 84, height: 84)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onDetailTap == nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(a11yLabel)
            .accessibilityHint(onDetailTap == nil ? "" : "Tap to see your journey")
        }
        .padding(18)
        .widgetCardStyle()
        .overlay(alignment: .topTrailing) {
            if onDetailTap != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Mandala

    @ViewBuilder
    private var mandala: some View {
        let dotCount = mandalaDotCount
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size / 2) - 8
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                ForEach(Array(0..<dotCount), id: \.self) { index in
                    mandalaDot(index: index, dotCount: dotCount)
                        .offset(
                            x: cos(angleFor(index: index, count: dotCount).radians) * radius,
                            y: sin(angleFor(index: index, count: dotCount).radians) * radius
                        )
                        .position(center)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func angleFor(index: Int, count: Int) -> Angle {
        Angle.degrees(Double(index) / Double(count) * 360 - 90)
    }

    @ViewBuilder
    private func mandalaDot(index: Int, dotCount: Int) -> some View {
        let isDone = index < cycleCount
        let isCurrent = isCurrentCyclePartial && index == cycleCount

        Circle()
            .fill(
                isDone
                    ? AnyShapeStyle(LinearGradient(
                        colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(DesignColors.text.opacity(isCurrent ? 0.18 : 0.08))
            )
            .frame(width: 9, height: 9)
            .overlay {
                if isCurrent {
                    Circle()
                        .strokeBorder(DesignColors.accentWarm.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 15, height: 15)
                }
            }
    }

    // MARK: - Accessibility

    private var a11yLabel: String {
        let meta: String
        if let day = currentCycleDay {
            meta = "cycle \(currentCycleNumber), day \(day)"
        } else {
            meta = "cycle \(currentCycleNumber)"
        }
        return "Journey, \(meta), \(cycleCount) \(cycleCount == 1 ? "cycle" : "cycles") tracked"
    }
}

// MARK: - Preview

#Preview("Early") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        JourneyWidget(
            cycleCount: 1,
            currentCycleNumber: 2,
            currentCycleDay: 12,
            onDetailTap: {}
        )
        .padding(18)
    }
}

#Preview("Mid") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        JourneyWidget(
            cycleCount: 4,
            currentCycleNumber: 5,
            currentCycleDay: 8,
            onDetailTap: {}
        )
        .padding(18)
    }
}

#Preview("Full Year") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        JourneyWidget(
            cycleCount: 12,
            currentCycleNumber: 13,
            currentCycleDay: 3,
            onDetailTap: {}
        )
        .padding(18)
    }
}
