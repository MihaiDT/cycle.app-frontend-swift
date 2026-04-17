import Inject
import SwiftUI

// MARK: - Professional Context

public enum ProfessionalContext: String, CaseIterable, Equatable, Sendable {
    case student = "Student"
    case employed = "Employed"
    case freelancer = "Freelancer"
    case entrepreneur = "Entrepreneur"
    case stayAtHome = "Stay-at-home mom"

    var subtitle: String {
        switch self {
        case .student: return "Learning & growing"
        case .employed: return "Stable career"
        case .freelancer: return "Creative freedom"
        case .entrepreneur: return "Building the future"
        case .stayAtHome: return "Present for family"
        }
    }
}

// MARK: - Professional Context View

public struct ProfessionalContextView: View {
    @ObserveInjection var inject
    @Binding public var selectedContext: ProfessionalContext?
    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    @State private var hasAppeared = false

    public init(
        selectedContext: Binding<ProfessionalContext?>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._selectedContext = selectedContext
        self.onNext = onNext
        self.onBack = onBack
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 6,
            totalSteps: 8,
            onBack: onBack,
            onNext: onNext,
            nextButtonEnabled: selectedContext != nil
        ) {
            VStack(spacing: 0) {
                // Elegant header
                VStack(spacing: 6) {
                    Text("one more thing")
                        .font(.raleway("Regular", size: 13, relativeTo: .caption))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(DesignColors.text.opacity(0.5))

                    Text("Your Lifestyle")
                        .font(.raleway("Bold", size: 32, relativeTo: .title))
                        .foregroundColor(DesignColors.text)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.bottom, 32)

                // Cards with slide-in animation
                ZStack {
                    ForEach(Array(ProfessionalContext.allCases.enumerated()), id: \.element) { index, context in
                        ProfessionalCard(
                            context: context,
                            isSelected: selectedContext == context,
                            hasSelection: selectedContext != nil,
                            index: index,
                            totalCount: ProfessionalContext.allCases.count,
                            hasAppeared: hasAppeared
                        ) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                selectedContext = context
                            }
                        }
                    }
                }
                .frame(height: selectedContext == nil ? 280 : 380)
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            // Staggered entrance animation
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                hasAppeared = true
            }
        }
        .enableInjection()
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

// MARK: - Professional Card

private struct ProfessionalCard: View {
    let context: ProfessionalContext
    let isSelected: Bool
    let hasSelection: Bool
    let index: Int
    let totalCount: Int
    let hasAppeared: Bool
    let action: () -> Void

    // Stacked position (no selection) vs expanded position
    private var yOffset: CGFloat {
        let centerIndex = CGFloat(totalCount - 1) / 2.0
        let relativeIndex = CGFloat(index) - centerIndex

        if hasSelection {
            // Expanded: spread out with more space
            return relativeIndex * 68
        } else {
            // Stacked: tight stack with overlap
            return relativeIndex * 42
        }
    }

    // Entrance from left/right alternating
    private var entranceOffset: CGFloat {
        guard !hasAppeared else { return 0 }
        let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
        return direction * 300
    }

    private var horizontalOffset: CGFloat {
        guard !hasSelection else { return 0 }
        guard hasAppeared else { return entranceOffset }
        // Subtle wave pattern when stacked
        let offsets: [CGFloat] = [5, -5, 7, -7, 0]
        return offsets[index % 5]
    }

    private var rotation: Double {
        guard !hasSelection else { return 0 }
        guard hasAppeared else {
            // Entrance rotation
            let direction: Double = index.isMultiple(of: 2) ? -1 : 1
            return direction * 15
        }
        // Slight rotation when stacked
        let rotations: [Double] = [-1.8, 1.5, -1.0, 1.8, -1.2]
        return rotations[index % 5]
    }

    private var cardScale: CGFloat {
        guard hasAppeared else { return 0.85 }
        if isSelected {
            return 1.03
        } else if !hasSelection {
            // Slight scale variation when stacked
            let scales: [CGFloat] = [0.98, 0.99, 1.0, 0.99, 0.98]
            return scales[index % 5]
        }
        return 1.0
    }

    private var cardOpacity: Double {
        guard hasAppeared else { return 0 }
        return 1
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [DesignColors.accentWarm, DesignColors.accentSecondary.opacity(0.4)]
                                : [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 12)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.rawValue)
                        .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                        .foregroundColor(DesignColors.text)

                    // Animated subtitle
                    Text(context.subtitle)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(isSelected ? 0.6 : 0))
                        .frame(height: isSelected ? nil : 0, alignment: .top)
                        .clipped()
                }
                .padding(.leading, 16)

                Spacer()

                // Consent-style checkbox
                ProfessionalCheckbox(isSelected: isSelected)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 20)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 20)
            .frame(height: isSelected ? 72 : 56)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignColors.accent.opacity(0.08))
                        .blur(radius: 12)
                        .offset(y: 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected
                                ? [DesignColors.accent.opacity(0.5), DesignColors.accent.opacity(0.15)]
                                : [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }
            .shadow(
                color: isSelected
                    ? DesignColors.accent.opacity(0.12)
                    : Color.black.opacity(0.08),
                radius: isSelected ? 16 : 8,
                x: 0,
                y: isSelected ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .offset(x: horizontalOffset, y: yOffset)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 0, z: 1))
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .zIndex(isSelected ? 100 : Double(totalCount - index))
        .animation(
            .spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.08),
            value: hasAppeared
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasSelection)
        .animation(.appBalanced, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.rawValue). \(context.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Professional Checkbox (Consent Style)

private struct ProfessionalCheckbox: View {
    let isSelected: Bool

    // Using accentWarm for better visibility and WCAG contrast
    private var checkmarkColor: Color {
        DesignColors.accentWarm
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
            // Full circle - visible when not selected (using accentSecondary for visibility)
            Circle()
                .stroke(DesignColors.accentSecondary.opacity(0.5), style: strokeStyle)
                .opacity(isSelected ? 0 : 1)

            // Circle with gap - visible when selected
            ProfessionalCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isSelected ? 1 : 0)

            // Checkmark - animated
            ProfessionalCheckmark(progress: isSelected ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Circle with Gap Shape

private struct ProfessionalCircleWithGap: Shape {
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

// MARK: - Checkmark Shape

private struct ProfessionalCheckmark: Shape {
    var animatableData: CGFloat

    init(progress: CGFloat = 1) {
        self.animatableData = progress
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 19.0

        var path = Path()
        path.move(to: CGPoint(x: 7.12517 * scale, y: 8.71606 * scale))
        path.addLine(to: CGPoint(x: 9.50017 * scale, y: 11.0911 * scale))
        path.addLine(to: CGPoint(x: 17.4168 * scale, y: 3.16648 * scale))

        return path.trimmedPath(from: 0, to: animatableData)
    }
}

// MARK: - Preview

#Preview("Professional Context - Empty") {
    ProfessionalContextView(
        selectedContext: .constant(nil),
        onNext: {},
        onBack: {}
    )
}

#Preview("Professional Context - Selected") {
    ProfessionalContextView(
        selectedContext: .constant(.freelancer),
        onNext: {},
        onBack: {}
    )
}
