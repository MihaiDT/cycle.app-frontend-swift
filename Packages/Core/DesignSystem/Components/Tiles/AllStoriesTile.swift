import SwiftUI

// MARK: - All Stories Tile
//
// Warm amber-cream tile that opens the full Journey screen with every
// past cycle + its recap. Decorative "winding road" illustration: a
// dashed path with colored dots representing tracked cycles. Pairs
// with `LatestStoryTile` on Home's Journey carousel page.

public struct AllStoriesTile: View {
    public let cycleCount: Int
    public let monthsLabel: String
    public let onTap: (() -> Void)?

    public init(
        cycleCount: Int,
        monthsLabel: String,
        onTap: (() -> Void)? = nil
    ) {
        self.cycleCount = cycleCount
        self.monthsLabel = monthsLabel
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            tileContent
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                .background(background)
                .overlay(border)
                .shadow(color: Color(hex: 0x8A5A1E).opacity(0.08), radius: 10, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All stories. \(cycleCount) \(cycleCount == 1 ? "cycle" : "cycles") tracked. \(monthsLabel)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            Spacer(minLength: 6)
            titleBlock
            Spacer(minLength: 8)
            bottomRow
        }
        .padding(18)
    }

    @ViewBuilder
    private var topRow: some View {
        HStack {
            Text("ALL STORIES")
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Color(hex: 0x8A5A1E).opacity(0.9))
            Spacer()
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your journey")
                .font(.raleway("Bold", size: 20, relativeTo: .title3))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .lineLimit(1)

            Text("Every story you've unfolded.")
                .font(.raleway("Medium", size: 13, relativeTo: .subheadline))
                .italic()
                .foregroundStyle(Color(hex: 0x4E3A1C))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var bottomRow: some View {
        HStack {
            Text("\(cycleCount) \(cycleCount == 1 ? "CYCLE" : "CYCLES") · \(monthsLabel)")
                .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                .tracking(0.5)
                .foregroundStyle(Color(hex: 0x8A5A1E))
                .lineLimit(1)

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x8A5A1E))
        }
    }

    @ViewBuilder
    private var background: some View {
        LinearGradient(
            colors: [Color(hex: 0xF7EFD8), Color(hex: 0xE6D4C4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var border: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color(hex: 0x8A5A1E).opacity(0.1), lineWidth: 1)
    }

    @ViewBuilder
    private var roadAsset: some View {
        WindingRoad()
            .frame(height: 82)
            .padding(.leading, -10)
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Winding Road (isolated view for compile speed)

private struct WindingRoad: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                roadPath(size: geo.size)
                roadDots(size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func roadPath(size: CGSize) -> some View {
        Path { path in
            let w = size.width
            let h = size.height
            path.move(to: CGPoint(x: w, y: h * 0.15))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.40),
                control: CGPoint(x: w * 0.85, y: h * 0.15)
            )
            path.addQuadCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.63),
                control: CGPoint(x: w * 0.65, y: h * 0.55)
            )
            path.addQuadCurve(
                to: CGPoint(x: w * 0.35, y: h * 0.40),
                control: CGPoint(x: w * 0.45, y: h * 0.55)
            )
            path.addQuadCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.25),
                control: CGPoint(x: w * 0.25, y: h * 0.30)
            )
            path.addQuadCurve(
                to: CGPoint(x: -w * 0.10, y: h * 0.50),
                control: CGPoint(x: w * 0.02, y: h * 0.35)
            )
        }
        .stroke(
            LinearGradient(
                colors: [
                    Color(hex: 0xE9D29F).opacity(0.7),
                    Color(hex: 0xC9A859).opacity(0.65),
                    Color(hex: 0x8A5A1E).opacity(0.55)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 5])
        )
    }

    @ViewBuilder
    private func roadDots(size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        ZStack {
            dot(x: w * 0.95, y: h * 0.15, color: 0x8A5A1E, opacity: 0.35, size: 6)
            dot(x: w * 0.75, y: h * 0.40, color: 0x8A5A1E, opacity: 0.50, size: 6)
            dot(x: w * 0.55, y: h * 0.63, color: 0xC9A859, opacity: 1.0, size: 6.5)
            dot(x: w * 0.35, y: h * 0.40, color: 0xE9D29F, opacity: 1.0, size: 6.5)
            dot(x: w * 0.15, y: h * 0.25, color: 0xF3C9C2, opacity: 1.0, size: 7)
            newestDot(x: w * 0.02, y: h * 0.45)
        }
    }

    @ViewBuilder
    private func dot(x: CGFloat, y: CGFloat, color: UInt, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: color).opacity(opacity))
            .frame(width: size, height: size)
            .position(x: x, y: y)
    }

    @ViewBuilder
    private func newestDot(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: 0x8C3E36))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 14, height: 14)
            )
            .position(x: x, y: y)
    }
}

// MARK: - Preview

#Preview("All Stories") {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        HStack {
            AllStoriesTile(
                cycleCount: 6,
                monthsLabel: "12 MONTHS",
                onTap: {}
            )
            .frame(width: 180)
            Spacer()
        }
        .padding(20)
    }
}
