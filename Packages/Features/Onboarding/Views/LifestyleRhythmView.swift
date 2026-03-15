import Inject
import SwiftUI

// MARK: - Lifestyle Type

public enum LifestyleType: Int, CaseIterable, Equatable, Sendable {
    case calm = 0
    case active = 1
    case intuitive = 2
    case analytical = 3

    var title: String {
        switch self {
        case .calm: return "Calm & Stable"
        case .active: return "Active & On-the-go"
        case .intuitive: return "Intuitive & Emotional"
        case .analytical: return "Mental & Analytical"
        }
    }

    var subtitle: String {
        switch self {
        case .calm: return "You prefer peace and routine"
        case .active: return "You thrive on movement"
        case .intuitive: return "You follow your heart"
        case .analytical: return "You lead with logic"
        }
    }

    // Angle on the arc (0° = left, 180° = right)
    var angle: Double {
        switch self {
        case .calm: return 22.5
        case .active: return 67.5
        case .intuitive: return 112.5
        case .analytical: return 157.5
        }
    }
}

// MARK: - Lifestyle Rhythm View

public struct LifestyleRhythmView: View {
    @ObserveInjection var inject
    @Binding public var selectedType: LifestyleType?
    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    @State private var dragAngle: Double = 90
    @State private var isDragging = false
    @GestureState private var dragState = false

    public init(
        selectedType: Binding<LifestyleType?>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._selectedType = selectedType
        self.onNext = onNext
        self.onBack = onBack
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 7,
            totalSteps: 8,
            onBack: onBack,
            onNext: onNext,
            nextButtonEnabled: selectedType != nil
        ) {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 30)

                // Header
                VStack(spacing: 6) {
                    Text("almost done")
                        .font(.custom("Raleway-Regular", size: 13))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(DesignColors.text.opacity(0.5))

                    Text("Your Rhythm")
                        .font(.custom("Raleway-Bold", size: 32))
                        .foregroundColor(DesignColors.text)
                }
                .padding(.bottom, 60)

                // Current selection display
                VStack(spacing: 20) {
                    // Title
                    Text(selectedType?.title ?? "Slide to select")
                        .font(.custom("Raleway-SemiBold", size: 24))
                        .foregroundColor(DesignColors.text)
                        .multilineTextAlignment(.center)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: selectedType)

                    // Subtitle
                    Text(selectedType?.subtitle ?? "Find your natural rhythm")
                        .font(.custom("Raleway-Regular", size: 17))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: selectedType)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .padding(.horizontal, 32)

                Spacer()

                // Arc wheel selector - Apple style
                AppleStyleArcSelector(
                    selectedType: $selectedType,
                    dragAngle: $dragAngle,
                    isDragging: $isDragging
                )
                .frame(height: 260)
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            // Restore drag angle from selected type when returning to this screen
            if let type = selectedType {
                dragAngle = type.angle
            }
        }
        .enableInjection()
    }
}

// MARK: - Apple Style Arc Selector

private struct AppleStyleArcSelector: View {
    @Binding var selectedType: LifestyleType?
    @Binding var dragAngle: Double
    @Binding var isDragging: Bool

    private let arcRadius: CGFloat = 180
    private let trackWidth: CGFloat = 80
    private let thumbSize: CGFloat = 36

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height + 40)

            ZStack {
                // Glass arc background
                ArcShape(center: center, radius: arcRadius, thickness: trackWidth)
                    .fill(.ultraThinMaterial)

                // Subtle gradient overlay
                ArcShape(center: center, radius: arcRadius, thickness: trackWidth)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Border
                ArcShape(center: center, radius: arcRadius, thickness: trackWidth)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)

                // Section highlights
                ForEach(LifestyleType.allCases, id: \.self) { type in
                    SectionHighlight(
                        type: type,
                        center: center,
                        radius: arcRadius,
                        thickness: trackWidth,
                        isSelected: selectedType == type
                    )
                }

                // Section dividers
                ForEach([45.0, 90.0, 135.0], id: \.self) { angle in
                    DividerLine(
                        angle: angle,
                        center: center,
                        innerRadius: arcRadius - trackWidth,
                        outerRadius: arcRadius
                    )
                }

                // Labels inside arc
                ForEach(LifestyleType.allCases, id: \.self) { type in
                    TypeLabel(
                        type: type,
                        center: center,
                        radius: arcRadius - trackWidth / 2,
                        isSelected: selectedType == type
                    )
                }

                // Thumb on the arc edge
                AppleThumb(
                    angle: max(10, min(170, dragAngle)),
                    center: center,
                    radius: arcRadius,
                    size: thumbSize,
                    isDragging: isDragging
                )
            }
            // Drag gesture on entire arc area
            .contentShape(ArcShape(center: center, radius: arcRadius + 50, thickness: trackWidth + 100))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                        isDragging = true

                        let newAngle = angleFromPoint(value.location, center: center)
                        let clampedAngle = max(10, min(170, newAngle))

                        let newType = typeForAngle(clampedAngle)
                        if newType != selectedType {
                            let selection = UISelectionFeedbackGenerator()
                            selection.selectionChanged()
                        }

                        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.9)) {
                            dragAngle = clampedAngle
                            selectedType = newType
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        if let type = selectedType {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                dragAngle = type.angle
                            }
                        }
                    }
            )
        }
    }

    private func angleFromPoint(_ point: CGPoint, center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = center.y - point.y
        var angle = atan2(dx, dy) * 180 / .pi
        angle = 90 + angle
        return angle
    }

    private func typeForAngle(_ angle: Double) -> LifestyleType {
        if angle < 45 {
            return .calm
        } else if angle < 90 {
            return .active
        } else if angle < 135 {
            return .intuitive
        } else {
            return .analytical
        }
    }
}

// MARK: - Arc Shape

private struct ArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let innerRadius = radius - thickness

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(360),
            endAngle: .degrees(180),
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Section Highlight

private struct SectionHighlight: View {
    let type: LifestyleType
    let center: CGPoint
    let radius: CGFloat
    let thickness: CGFloat
    let isSelected: Bool

    private var startAngle: Double {
        switch type {
        case .calm: return 0
        case .active: return 45
        case .intuitive: return 90
        case .analytical: return 135
        }
    }

    var body: some View {
        SectionShape(
            center: center,
            radius: radius,
            thickness: thickness,
            startAngle: startAngle,
            endAngle: startAngle + 45
        )
        .fill(DesignColors.accent.opacity(isSelected ? 0.25 : 0))
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

private struct SectionShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let thickness: CGFloat
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let innerRadius = radius - thickness

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180 + startAngle),
            endAngle: .degrees(180 + endAngle),
            clockwise: false
        )

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(180 + endAngle),
            endAngle: .degrees(180 + startAngle),
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Divider Line

private struct DividerLine: View {
    let angle: Double
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    var body: some View {
        Path { path in
            let radians = (180 + angle) * .pi / 180
            let innerPoint = CGPoint(
                x: center.x + innerRadius * cos(radians),
                y: center.y + innerRadius * sin(radians)
            )
            let outerPoint = CGPoint(
                x: center.x + outerRadius * cos(radians),
                y: center.y + outerRadius * sin(radians)
            )
            path.move(to: innerPoint)
            path.addLine(to: outerPoint)
        }
        .stroke(Color.white.opacity(0.15), lineWidth: 1)
    }
}

// MARK: - Type Label

private struct TypeLabel: View {
    let type: LifestyleType
    let center: CGPoint
    let radius: CGFloat
    let isSelected: Bool

    private var position: CGPoint {
        let radians = (180 + type.angle) * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    private var shortLabel: String {
        switch type {
        case .calm: return "Calm"
        case .active: return "Active"
        case .intuitive: return "Intuitive"
        case .analytical: return "Analytical"
        }
    }

    var body: some View {
        Text(shortLabel)
            .font(.custom("Raleway-SemiBold", size: isSelected ? 15 : 13))
            .foregroundColor(isSelected ? DesignColors.text : DesignColors.text.opacity(0.5))
            .position(position)
            .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Apple Thumb

private struct AppleThumb: View {
    let angle: Double
    let center: CGPoint
    let radius: CGFloat
    let size: CGFloat
    let isDragging: Bool

    private var position: CGPoint {
        let radians = (180 + angle) * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: size, height: size)
                .blur(radius: 4)
                .offset(y: 2)

            // Main thumb
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)

            // Inner accent dot
            Circle()
                .fill(DesignColors.accent)
                .frame(width: size * 0.4, height: size * 0.4)
        }
        .position(position)
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .shadow(color: DesignColors.accent.opacity(isDragging ? 0.4 : 0), radius: 8)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isDragging)
    }
}

// MARK: - Preview

#Preview("Lifestyle Rhythm - Empty") {
    LifestyleRhythmView(
        selectedType: .constant(nil),
        onNext: {},
        onBack: {}
    )
}

#Preview("Lifestyle Rhythm - Selected") {
    LifestyleRhythmView(
        selectedType: .constant(.intuitive),
        onNext: {},
        onBack: {}
    )
}
