import SwiftUI

// MARK: - Checkbox Full Circle (unchecked state)

/// Complete circle outline for unchecked state
private struct CheckboxFullCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 2.0  // Match stroke width
        return Path(ellipseIn: rect.insetBy(dx: inset, dy: inset))
    }
}

// MARK: - Checkbox Circle with Gap (checked state)

/// Circle outline with gap for checkmark - exact SVG bezier path conversion
private struct CheckboxCircleWithGap: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0

        var path = Path()

        // Exact SVG path: M17.4168 8.77148 V9.49981 then bezier curves
        path.move(to: CGPoint(x: 17.4168 * scale, y: 8.77148 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 9.49981 * scale))

        // Bezier curves tracing the circle (clockwise from right to upper-right)
        path.addCurve(
            to: CGPoint(x: 15.8409 * scale, y: 14.2354 * scale),
            control1: CGPoint(x: 17.4159 * scale, y: 11.207 * scale),
            control2: CGPoint(x: 16.8631 * scale, y: 12.8681 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 11.7448 * scale, y: 17.0871 * scale),
            control1: CGPoint(x: 14.8187 * scale, y: 15.6027 * scale),
            control2: CGPoint(x: 13.3819 * scale, y: 16.603 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 6.75662 * scale, y: 16.9214 * scale),
            control1: CGPoint(x: 10.1077 * scale, y: 17.5711 * scale),
            control2: CGPoint(x: 8.35799 * scale, y: 17.513 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 2.85884 * scale, y: 13.8042 * scale),
            control1: CGPoint(x: 5.15524 * scale, y: 16.3297 * scale),
            control2: CGPoint(x: 3.78801 * scale, y: 15.2363 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 1.60066 * scale, y: 8.97439 * scale),
            control1: CGPoint(x: 1.92967 * scale, y: 12.372 * scale),
            control2: CGPoint(x: 1.48833 * scale, y: 10.6779 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 3.48213 * scale, y: 4.35166 * scale),
            control1: CGPoint(x: 1.71298 * scale, y: 7.27093 * scale),
            control2: CGPoint(x: 2.37295 * scale, y: 5.6494 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 7.75548 * scale, y: 1.77326 * scale),
            control1: CGPoint(x: 4.59132 * scale, y: 3.05392 * scale),
            control2: CGPoint(x: 6.09028 * scale, y: 2.14949 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 12.7223 * scale, y: 2.26398 * scale),
            control1: CGPoint(x: 9.42067 * scale, y: 1.39703 * scale),
            control2: CGPoint(x: 11.1629 * scale, y: 1.56916 * scale)
        )

        return path
    }
}

// MARK: - Checkbox Checkmark (Animated)

/// Checkmark path for checkbox - animates in
private struct CheckboxCheckmark: Shape {
    var animatableData: CGFloat

    init(progress: CGFloat = 1) {
        self.animatableData = progress
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0

        var path = Path()
        // Checkmark from SVG - reversed to animate from bottom-left to top-right
        path.move(to: CGPoint(x: 7.12517 * scale, y: 8.71606 * scale))
        path.addLine(to: CGPoint(x: 9.50017 * scale, y: 11.0911 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 3.16648 * scale))

        return path.trimmedPath(from: 0, to: animatableData)
    }
}

// MARK: - Animated Checkbox Icon

private struct AnimatedCheckboxIcon: View {
    let isChecked: Bool

    private var checkmarkColor: Color {
        Color(red: 122 / 255, green: 95 / 255, blue: 80 / 255)  // #7A5F50
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 1.78125 * (24.0 / 19.0),
            lineCap: .round,
            lineJoin: .round
        )
    }

    var body: some View {
        ZStack {
            // Full circle - visible when unchecked
            CheckboxFullCircle()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isChecked ? 0 : 1)

            // Circle with gap - visible when checked
            CheckboxCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isChecked ? 1 : 0)

            // Checkmark - animated
            CheckboxCheckmark(progress: isChecked ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isChecked)
        }
        .animation(.easeOut(duration: 0.15), value: isChecked)
    }
}

// MARK: - Consent Checkbox

public struct ConsentCheckbox<Content: View>: View {
    public let isChecked: Bool
    public let action: () -> Void
    @ViewBuilder public let content: () -> Content

    public init(
        isChecked: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isChecked = isChecked
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                AnimatedCheckboxIcon(isChecked: isChecked)
                    .frame(width: 24, height: 24)
                    .frame(width: 44, height: 44)

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview("Consent Checkbox") {
    VStack(spacing: 20) {
        ConsentCheckbox(isChecked: false, action: {}) {
            Text("Unchecked state")
        }

        ConsentCheckbox(isChecked: true, action: {}) {
            Text("Checked state")
        }
    }
    .padding()
}
