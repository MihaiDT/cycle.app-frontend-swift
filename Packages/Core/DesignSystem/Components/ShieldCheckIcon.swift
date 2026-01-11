import SwiftUI

// MARK: - Shield Check Icon

public struct ShieldCheckIcon: View {
    public init() {}

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: 0xDCBFB5),
                Color(hex: 0xD6A59A),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 237

            // Shield path
            var shieldPath = Path()
            shieldPath.move(to: CGPoint(x: 126.133 * scale, y: 36.598 * scale))

            // Right side curve to top
            shieldPath.addCurve(
                to: CGPoint(x: 192.562 * scale, y: 61.899 * scale),
                control1: CGPoint(x: 185.232 * scale, y: 52.358 * scale),
                control2: CGPoint(x: 192.562 * scale, y: 57.425 * scale)
            )

            // Down to bottom curve area
            shieldPath.addLine(to: CGPoint(x: 192.562 * scale, y: 121.353 * scale))

            // Shield bottom curves
            shieldPath.addCurve(
                to: CGPoint(x: 166.178 * scale, y: 170.652 * scale),
                control1: CGPoint(x: 192.562 * scale, y: 141.163 * scale),
                control2: CGPoint(x: 182.662 * scale, y: 159.663 * scale)
            )

            // To center bottom
            shieldPath.addLine(to: CGPoint(x: 123.978 * scale, y: 198.786 * scale))

            shieldPath.addCurve(
                to: CGPoint(x: 113.022 * scale, y: 198.786 * scale),
                control1: CGPoint(x: 120.661 * scale, y: 200.997 * scale),
                control2: CGPoint(x: 116.339 * scale, y: 200.997 * scale)
            )

            // Left side
            shieldPath.addLine(to: CGPoint(x: 70.822 * scale, y: 170.652 * scale))

            shieldPath.addCurve(
                to: CGPoint(x: 44.438 * scale, y: 121.353 * scale),
                control1: CGPoint(x: 54.338 * scale, y: 159.663 * scale),
                control2: CGPoint(x: 44.438 * scale, y: 141.163 * scale)
            )

            shieldPath.addLine(to: CGPoint(x: 44.438 * scale, y: 61.899 * scale))

            shieldPath.addCurve(
                to: CGPoint(x: 51.768 * scale, y: 52.358 * scale),
                control1: CGPoint(x: 44.438 * scale, y: 57.425 * scale),
                control2: CGPoint(x: 47.445 * scale, y: 53.510 * scale)
            )

            shieldPath.addLine(to: CGPoint(x: 110.867 * scale, y: 36.598 * scale))

            shieldPath.addCurve(
                to: CGPoint(x: 126.133 * scale, y: 36.598 * scale),
                control1: CGPoint(x: 115.868 * scale, y: 35.264 * scale),
                control2: CGPoint(x: 121.132 * scale, y: 35.264 * scale)
            )

            // Checkmark path
            var checkPath = Path()
            checkPath.move(to: CGPoint(x: 93.812 * scale, y: 113.562 * scale))
            checkPath.addLine(to: CGPoint(x: 111.817 * scale, y: 131.567 * scale))
            checkPath.addCurve(
                to: CGPoint(x: 115.308 * scale, y: 131.567 * scale),
                control1: CGPoint(x: 112.781 * scale, y: 132.531 * scale),
                control2: CGPoint(x: 114.344 * scale, y: 132.531 * scale)
            )
            checkPath.addLine(to: CGPoint(x: 148.125 * scale, y: 98.75 * scale))

            // Draw shield stroke
            context.stroke(
                shieldPath,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xDCBFB5), Color(hex: 0xD6A59A)]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                ),
                style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round)
            )

            // Draw checkmark stroke
            context.stroke(
                checkPath,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xDCBFB5), Color(hex: 0xD6A59A)]),
                    startPoint: CGPoint(x: size.width, y: size.height / 2),
                    endPoint: CGPoint(x: 0, y: size.height / 2)
                ),
                style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("Shield Check Icon") {
    ShieldCheckIcon()
        .frame(width: 237, height: 237)
}
