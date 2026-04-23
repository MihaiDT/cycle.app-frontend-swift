import SwiftUI

import SwiftUI

// MARK: - Animated Checkbox Components (for Regularity Sheet)

private struct RegularityCheckboxFullCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 2.0
        return Path(ellipseIn: rect.insetBy(dx: inset, dy: inset))
    }
}

private struct RegularityCheckboxCircleWithGap: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0
        var path = Path()
        path.move(to: CGPoint(x: 17.4168 * scale, y: 8.77148 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 9.49981 * scale))
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

private struct RegularityCheckboxCheckmark: Shape {
    var animatableData: CGFloat
    init(progress: CGFloat = 1) { self.animatableData = progress }
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0
        var path = Path()
        path.move(to: CGPoint(x: 7.12517 * scale, y: 8.71606 * scale))
        path.addLine(to: CGPoint(x: 9.50017 * scale, y: 11.0911 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 3.16648 * scale))
        return path.trimmedPath(from: 0, to: animatableData)
    }
}

struct RegularityCheckboxIcon: View {
    let isChecked: Bool
    private var checkmarkColor: Color { DesignColors.link }
    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1.78125 * (24.0 / 19.0), lineCap: .round, lineJoin: .round)
    }
    var body: some View {
        ZStack {
            RegularityCheckboxFullCircle()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isChecked ? 0 : 1)
            RegularityCheckboxCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isChecked ? 1 : 0)
            RegularityCheckboxCheckmark(progress: isChecked ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isChecked)
        }
        .animation(.easeOut(duration: 0.15), value: isChecked)
    }
}


// MARK: - Cycle Data Page Container

struct CycleDataPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                Text(title)
                    .font(.raleway("Bold", size: 26, relativeTo: .title2))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Spacer().frame(height: 8)

                Text(subtitle)
                    .font(.raleway("Regular", size: 15, relativeTo: .body))
                    .foregroundColor(DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 32)

                content

                Spacer().frame(height: 120)
            }
        }
    }
}

