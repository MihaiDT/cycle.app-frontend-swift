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


// MARK: - Duration Stepper

struct DurationStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    
    @State private var isIncrementing: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundColor(DesignColors.text.opacity(0.7))

            HStack(spacing: 24) {
                Button(action: {
                    if value > range.lowerBound {
                        isIncrementing = false
                        value -= 1
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(
                            value > range.lowerBound ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.4)
                        )
                }
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Decrease \(label)")

                VStack(spacing: 4) {
                    Text("\(value)")
                        .font(.raleway("Bold", size: 48, relativeTo: .largeTitle))
                        .foregroundColor(DesignColors.text)
                        .contentTransition(.numericText(countsDown: !isIncrementing))
                        .animation(.appBalanced, value: value)
                    Text(unit)
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }
                .frame(width: 100)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(value) \(unit)")

                Button(action: {
                    if value < range.upperBound {
                        isIncrementing = true
                        value += 1
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(
                            value < range.upperBound ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.4)
                        )
                }
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Increase \(label)")
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Regularity Option Button (Glass style matching other onboarding screens)

struct RegularityOptionButton: View {
    let regularity: CycleRegularity
    let isSelected: Bool
    let action: () -> Void

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
                    Text(regularity.displayName)
                        .font(.raleway("SemiBold", size: 17, relativeTo: .body))
                        .foregroundColor(DesignColors.text)

                    // Animated subtitle
                    Text(regularity.description)
                        .font(.raleway("Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(isSelected ? 0.6 : 0))
                        .frame(height: isSelected ? nil : 0, alignment: .top)
                        .clipped()
                }
                .padding(.leading, 16)

                Spacer()

                // Consent-style checkbox
                RegularityCheckbox(isSelected: isSelected)
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
                        .fill(DesignColors.accentWarm.opacity(0.08))
                        .blur(radius: 12)
                        .offset(y: 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected
                                ? [DesignColors.accentWarm.opacity(0.5), DesignColors.accentSecondary.opacity(0.15)]
                                : [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }
            .shadow(
                color: isSelected
                    ? DesignColors.accentWarm.opacity(0.12)
                    : Color.black.opacity(0.08),
                radius: isSelected ? 16 : 8,
                x: 0,
                y: isSelected ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .animation(.appBalanced, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(regularity.displayName). \(regularity.description)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Regularity Checkbox (Consent Style)

private struct RegularityCheckbox: View {
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
            // Full circle - visible when not selected
            Circle()
                .stroke(DesignColors.accentSecondary.opacity(0.5), style: strokeStyle)
                .opacity(isSelected ? 0 : 1)

            // Circle with gap - visible when selected
            RegularityCircleWithGap()
                .stroke(checkmarkColor, style: strokeStyle)
                .opacity(isSelected ? 1 : 0)

            // Checkmark - animated
            RegularityCheckmark(progress: isSelected ? 1 : 0)
                .stroke(checkmarkColor, style: strokeStyle)
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Regularity Circle with Gap Shape

private struct RegularityCircleWithGap: Shape {
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

// MARK: - Regularity Checkmark Shape

private struct RegularityCheckmark: Shape {
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

// MARK: - Inline Symptoms Selector

struct InlineSymptomsSelector: View {
    @Binding var selectedSymptoms: Set<SymptomType>

    // Use all symptoms from each category
    private let categories: [(String, [SymptomType])] = [
        ("Physical", SymptomType.physicalSymptoms),
        ("Digestive", SymptomType.digestiveSymptoms),
        ("Mood", SymptomType.moodSymptoms),
        ("Energy", SymptomType.energySymptoms),
        ("Sleep", SymptomType.sleepSymptoms),
        ("Skin", SymptomType.skinSymptoms),
        ("Hair", SymptomType.hairSymptoms),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(categories, id: \.0) { category, symptoms in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category)
                            .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                            .foregroundColor(DesignColors.text.opacity(0.6))
                            .padding(.horizontal, 32)
                            .accessibilityAddTraits(.isHeader)

                        FlowLayout(spacing: 10) {
                            ForEach(symptoms) { symptom in
                                SymptomChip(
                                    symptom: symptom,
                                    isSelected: selectedSymptoms.contains(symptom)
                                ) {
                                    withAnimation(.appBalanced) {
                                        if selectedSymptoms.contains(symptom) {
                                            selectedSymptoms.remove(symptom)
                                        } else {
                                            selectedSymptoms.insert(symptom)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
    }
}

// MARK: - Inline Contraception Selector

struct InlineContraceptionSelector: View {
    @Binding var usesContraception: Bool
    @Binding var contraceptionType: ContraceptionType?

    var body: some View {
        VStack(spacing: 16) {
            FlowLayout(spacing: 10) {
                // None option
                Button(action: {
                    withAnimation(.appBalanced) {
                        usesContraception = false
                        contraceptionType = nil
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Text("None")
                        .font(.raleway("Medium", size: 14, relativeTo: .body))
                        .foregroundColor(!usesContraception ? DesignColors.text : DesignColors.text.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .strokeBorder(
                                    !usesContraception ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.4),
                                    lineWidth: !usesContraception ? 1.5 : 1
                                )
                                .background(
                                    Capsule().fill(!usesContraception ? DesignColors.accentWarm.opacity(0.15) : Color.white.opacity(0.5))
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("No contraception")
                .accessibilityAddTraits(!usesContraception ? [.isSelected, .isButton] : [.isButton])

                // Contraception types
                ForEach(ContraceptionType.allCases) { type in
                    Button(action: {
                        withAnimation(.appBalanced) {
                            usesContraception = true
                            contraceptionType = type
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        Text(type.displayName)
                            .font(.raleway("Medium", size: 14, relativeTo: .body))
                            .foregroundColor(contraceptionType == type ? DesignColors.text : DesignColors.text.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .strokeBorder(
                                        contraceptionType == type ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.4),
                                        lineWidth: contraceptionType == type ? 1.5 : 1
                                    )
                                    .background(
                                        Capsule().fill(
                                            contraceptionType == type ? DesignColors.accentWarm.opacity(0.15) : Color.white.opacity(0.5)
                                        )
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(type.displayName)
                    .accessibilityAddTraits(contraceptionType == type ? [.isSelected, .isButton] : [.isButton])
                }
            }
        }
    }
}

// MARK: - Glass Duration Button

private struct GlassDurationButton: View {
    let label: String
    let value: String
    let unit: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
                    .foregroundColor(DesignColors.text.opacity(0.6))

                HStack(spacing: 4) {
                    Text(value)
                        .font(.raleway("Bold", size: 24, relativeTo: .title2))
                        .foregroundColor(accentColor)

                    Text(unit)
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Selection Button

private struct GlassSelectionButton: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.6))

                    Text(value)
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Intensity Selector

struct FlowIntensitySelector: View {
    @Binding var intensity: Int

    private var intensityLabel: String {
        switch intensity {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Heavy"
        case 5: return "Very Heavy"
        default: return "Moderate"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flow intensity")
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.6))

                    Text(intensityLabel)
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Flow intensity: \(intensityLabel)")

                Spacer()
            }

            // Intensity dots
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { level in
                    Button(action: {
                        withAnimation(.appBalanced) {
                            intensity = level
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        Circle()
                            .fill(level <= intensity ? DesignColors.accent : DesignColors.text.opacity(0.15))
                            .frame(width: 20 + CGFloat(level) * 6, height: 20 + CGFloat(level) * 6)
                            .overlay {
                                if level == intensity {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Flow level \(level) of 5")
                    .accessibilityAddTraits(level == intensity ? [.isSelected, .isButton] : [.isButton])
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Glass Symptoms Button

private struct GlassSymptomsButton: View {
    let selectedSymptoms: Set<SymptomType>
    let action: () -> Void

    private var symptomNames: String {
        let sorted = selectedSymptoms.sorted { $0.displayName < $1.displayName }
        return sorted.map { $0.displayName }.joined(separator: ", ")
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if selectedSymptoms.isEmpty {
                    Text("Add typical symptoms")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                } else {
                    Text(symptomNames)
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .frame(height: 57)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Contraception Button

private struct GlassContraceptionButton: View {
    let usesContraception: Bool
    let contraceptionType: ContraceptionType?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if usesContraception, let type = contraceptionType {
                    Text(type.displayName)
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                } else if usesContraception {
                    Text("Using contraception")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.8))
                } else {
                    Text("Not using contraception")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .frame(height: 57)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + rowHeight
        }
    }
}

