import SwiftUI

// MARK: - Duration Picker Sheet

struct DurationPickerSheet: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.custom("Raleway-Bold", size: 22))
                        .foregroundColor(DesignColors.text)

                    Text(subtitle)
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                Picker(title, selection: $value) {
                    ForEach(Array(range), id: \.self) { num in
                        Text("\(num) \(unit)")
                            .font(.custom("Raleway-Medium", size: 20))
                            .tag(num)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)

                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.custom("Raleway-SemiBold", size: 17))
                    .foregroundColor(DesignColors.link)
                }
            }
        }
    }
}

// MARK: - Regularity Picker Sheet

struct RegularityPickerSheet: View {
    @Binding var selectedRegularity: CycleRegularity
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("How regular is your cycle?")
                    .font(.custom("Raleway-Bold", size: 20))
                    .foregroundColor(DesignColors.text)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    ForEach(CycleRegularity.allCases) { regularity in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedRegularity = regularity
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(regularity.displayName)
                                        .font(.custom("Raleway-SemiBold", size: 16))
                                        .foregroundColor(DesignColors.text)

                                    Text(regularity.description)
                                        .font(.custom("Raleway-Regular", size: 13))
                                        .foregroundColor(DesignColors.text.opacity(0.6))
                                }

                                Spacer()

                                RegularityCheckboxIcon(isChecked: selectedRegularity == regularity)
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        selectedRegularity == regularity
                                            ? DesignColors.accent.opacity(0.1)
                                            : Color(UIColor.secondarySystemGroupedBackground)
                                    )
                            )
                            .overlay {
                                if selectedRegularity == regularity {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(DesignColors.accent, lineWidth: 1.5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.custom("Raleway-SemiBold", size: 17))
                    .foregroundColor(DesignColors.link)
                }
            }
        }
    }
}

// MARK: - Symptoms Selection Sheet

struct SymptomsSelectionSheet: View {
    @Binding var selectedSymptoms: Set<SymptomType>
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Physical Symptoms
                    symptomSection(title: "Physical", symptoms: SymptomType.physicalSymptoms)

                    // Digestive Symptoms
                    symptomSection(title: "Digestive", symptoms: SymptomType.digestiveSymptoms)

                    // Mood Symptoms
                    symptomSection(title: "Mood", symptoms: SymptomType.moodSymptoms)

                    // Energy & Stress
                    symptomSection(title: "Energy & Stress", symptoms: SymptomType.energySymptoms)

                    // Sleep
                    symptomSection(title: "Sleep", symptoms: SymptomType.sleepSymptoms)

                    // Skin
                    symptomSection(title: "Skin", symptoms: SymptomType.skinSymptoms)

                    // Hair
                    symptomSection(title: "Hair", symptoms: SymptomType.hairSymptoms)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Typical Symptoms")
                        .font(.custom("Raleway-Bold", size: 18))
                        .foregroundColor(DesignColors.text)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.custom("Raleway-SemiBold", size: 17))
                    .foregroundColor(DesignColors.link)
                }
            }
        }
    }

    @ViewBuilder
    private func symptomSection(title: String, symptoms: [SymptomType]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("Raleway-SemiBold", size: 16))
                .foregroundColor(DesignColors.text)

            FlowLayout(spacing: 10) {
                ForEach(symptoms) { symptom in
                    SymptomChip(
                        symptom: symptom,
                        isSelected: selectedSymptoms.contains(symptom),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedSymptoms.contains(symptom) {
                                    selectedSymptoms.remove(symptom)
                                } else {
                                    selectedSymptoms.insert(symptom)
                                }
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Symptom Chip

struct SymptomChip: View {
    let symptom: SymptomType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let customIcon = symptom.customIcon {
                    Image(customIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: symptom.sfSymbol)
                        .font(.system(size: 20))
                }
                Text(symptom.displayName)
                    .font(.custom("Raleway-Medium", size: 14))
            }
            .foregroundColor(isSelected ? DesignColors.text : DesignColors.text.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .strokeBorder(
                        isSelected ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.4),
                        lineWidth: isSelected ? 1.5 : 1
                    )
                    .background(
                        Capsule()
                            .fill(isSelected ? DesignColors.accentWarm.opacity(0.15) : Color.white.opacity(0.5))
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contraception Picker Sheet

struct ContraceptionPickerSheet: View {
    @Binding var usesContraception: Bool
    @Binding var contraceptionType: ContraceptionType?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Contraception")
                    .font(.custom("Raleway-Bold", size: 20))
                    .foregroundColor(DesignColors.text)
                    .padding(.top, 8)

                FlowLayout(spacing: 10) {
                    // None option
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            usesContraception = false
                            contraceptionType = nil
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        Text("None")
                            .font(.custom("Raleway-Medium", size: 14))
                            .foregroundColor(
                                !usesContraception ? DesignColors.accent : .primary.opacity(0.7)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background {
                                Capsule()
                                    .strokeBorder(
                                        !usesContraception
                                            ? DesignColors.accent : Color.gray.opacity(0.3),
                                        lineWidth: !usesContraception ? 1.5 : 1
                                    )
                                    .background(
                                        Capsule()
                                            .fill(
                                                !usesContraception
                                                    ? DesignColors.accent.opacity(0.1) : Color.clear
                                            )
                                    )
                            }
                    }
                    .buttonStyle(.plain)

                    // Contraception types
                    ForEach(ContraceptionType.allCases) { type in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                usesContraception = true
                                contraceptionType = type
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            Text(type.displayName)
                                .font(.custom("Raleway-Medium", size: 14))
                                .foregroundColor(
                                    contraceptionType == type ? DesignColors.accent : .primary.opacity(0.7)
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    Capsule()
                                        .strokeBorder(
                                            contraceptionType == type
                                                ? DesignColors.accent : Color.gray.opacity(0.3),
                                            lineWidth: contraceptionType == type ? 1.5 : 1
                                        )
                                        .background(
                                            Capsule()
                                                .fill(
                                                    contraceptionType == type
                                                        ? DesignColors.accent.opacity(0.1) : Color.clear
                                                )
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.custom("Raleway-SemiBold", size: 17))
                    .foregroundColor(DesignColors.link)
                }
            }
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(UIColor.systemGroupedBackground))
    }
}

