import SwiftUI

// MARK: - Relationship Status

public enum RelationshipStatus: String, CaseIterable, Equatable, Sendable {
    case single = "Single"
    case inRelationship = "In a relationship"
    case married = "Married"
    case separated = "Separated"
    case divorced = "Divorced"

    var subtitle: String {
        switch self {
        case .single: return "Free spirit, open heart"
        case .inRelationship: return "Building something beautiful"
        case .married: return "Committed & cherished"
        case .separated: return "Finding myself again"
        case .divorced: return "New chapter, fresh start"
        }
    }
}

// MARK: - Relationship Status View

public struct RelationshipStatusView: View {
    @Binding public var selectedStatus: RelationshipStatus?
    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    public init(
        selectedStatus: Binding<RelationshipStatus?>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._selectedStatus = selectedStatus
        self.onNext = onNext
        self.onBack = onBack
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 5,
            totalSteps: 8,
            onBack: onBack,
            onNext: onNext,
            nextButtonEnabled: selectedStatus != nil
        ) {
            VStack(spacing: 0) {
                // Elegant header
                VStack(spacing: 6) {
                    Text("almost there")
                        .font(.custom("Raleway-Regular", size: 13))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(DesignColors.text.opacity(0.5))

                    Text("Your Story")
                        .font(.custom("Raleway-Bold", size: 32))
                        .foregroundColor(DesignColors.text)
                }
                .padding(.bottom, 32)

                // Cards that stack/expand
                ZStack {
                    ForEach(Array(RelationshipStatus.allCases.enumerated()), id: \.element) { index, status in
                        LuxuryStatusCard(
                            status: status,
                            isSelected: selectedStatus == status,
                            hasSelection: selectedStatus != nil,
                            index: index,
                            totalCount: RelationshipStatus.allCases.count
                        ) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                selectedStatus = status
                            }
                        }
                    }
                }
                .frame(height: selectedStatus == nil ? 280 : 380)
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Luxury Status Card

private struct LuxuryStatusCard: View {
    let status: RelationshipStatus
    let isSelected: Bool
    let hasSelection: Bool
    let index: Int
    let totalCount: Int
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

    private var horizontalOffset: CGFloat {
        guard !hasSelection else { return 0 }
        // Subtle wave pattern when stacked
        let offsets: [CGFloat] = [4, -4, 6, -6, 0]
        return offsets[index % 5]
    }

    private var rotation: Double {
        guard !hasSelection else { return 0 }
        // Slight rotation when stacked
        let rotations: [Double] = [-1.5, 1.2, -0.8, 1.5, -1.0]
        return rotations[index % 5]
    }

    private var cardScale: CGFloat {
        if isSelected {
            return 1.03
        } else if !hasSelection {
            // Slight scale variation when stacked
            let scales: [CGFloat] = [0.98, 0.99, 1.0, 0.99, 0.98]
            return scales[index % 5]
        }
        return 1.0
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [DesignColors.accent, DesignColors.accent.opacity(0.4)]
                                : [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 12)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.rawValue)
                        .font(.custom("Raleway-SemiBold", size: 17))
                        .foregroundColor(DesignColors.text)

                    // Animated subtitle
                    Text(status.subtitle)
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(DesignColors.text.opacity(isSelected ? 0.6 : 0))
                        .frame(height: isSelected ? nil : 0, alignment: .top)
                        .clipped()
                }
                .padding(.leading, 16)

                Spacer()

                // Consent-style checkbox
                SelectionCheckbox(isSelected: isSelected)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 20)
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
        .zIndex(isSelected ? 100 : Double(totalCount - index))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasSelection)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Selection Checkbox (Consent Style)

private struct SelectionCheckbox: View {
    let isSelected: Bool

    private var checkmarkColor: Color {
        DesignColors.accent
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
            // Full circle - visible when not selected
            Circle()
                .stroke(Color.white.opacity(0.3), style: strokeStyle)
                .opacity(isSelected ? 0 : 1)

            // Circle with gap - visible when selected
            CheckboxCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isSelected ? 1 : 0)

            // Checkmark - animated
            CheckboxCheckmark(progress: isSelected ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Checkbox Circle with Gap

private struct CheckboxCircleWithGap: Shape {
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

// MARK: - Checkbox Checkmark

private struct CheckboxCheckmark: Shape {
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

#Preview {
    RelationshipStatusView(
        selectedStatus: .constant(.inRelationship),
        onNext: {},
        onBack: {}
    )
}
