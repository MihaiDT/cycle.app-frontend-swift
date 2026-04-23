import SwiftUI

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

