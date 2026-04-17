import ComposableArchitecture
import SwiftUI

// MARK: - Symptom Categories

enum SymptomCategory: String, CaseIterable {
    case physical = "Physical"
    case mood = "Mood"
    case energy = "Energy"
    case sleep = "Sleep"
    case digestive = "Digestive"
    case skin = "Skin & Hair"

    var icon: String {
        switch self {
        case .physical: "figure.run"
        case .mood: "face.smiling"
        case .energy: "bolt.circle"
        case .sleep: "moon.zzz"
        case .digestive: "fork.knife"
        case .skin: "hands.and.sparkles.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .physical: DesignColors.accentWarm
        case .mood: DesignColors.roseTaupe
        case .energy: DesignColors.accentSecondary
        case .sleep: DesignColors.textCard
        case .digestive: DesignColors.structure
        case .skin: DesignColors.accent
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .physical: [DesignColors.background, DesignColors.accent.opacity(0.08)]
        case .mood: [DesignColors.background, DesignColors.roseTaupeLight.opacity(0.12)]
        case .energy: [DesignColors.background, DesignColors.accentSecondary.opacity(0.06)]
        case .sleep: [DesignColors.background, DesignColors.textCard.opacity(0.06)]
        case .digestive: [DesignColors.background, DesignColors.structure.opacity(0.08)]
        case .skin: [DesignColors.background, DesignColors.accent.opacity(0.1)]
        }
    }

    var symptoms: [SymptomType] {
        switch self {
        case .physical:
            [
                .cramping, .headache, .backPain, .bloating, .breastTenderness, .nausea,
                .acne, .dizziness, .hotFlashes, .jointPain, .allGood, .fever,
            ]
        case .mood:
            [
                .calm, .happy, .sensitive, .sad, .apathetic, .tired, .angry,
                .lively, .motivated, .anxious, .confident, .irritable, .emotional, .moodSwings,
            ]
        case .energy:
            [.lowEnergy, .normalEnergy, .highEnergy, .noStress, .manageableStress, .intenseStress]
        case .sleep:
            [.peacefulSleep, .difficultyFallingAsleep, .restlessSleep, .insomnia]
        case .digestive:
            [.constipation, .diarrhea, .appetiteChanges, .cravings, .hunger]
        case .skin:
            [
                .normalSkin, .drySkin, .oilySkin, .skinBreakouts, .itchySkin,
                .normalHair, .shinyHair, .oilyHair, .dryHair, .hairLoss,
            ]
        }
    }
}

// MARK: - Symptom Logging Sheet

struct SymptomLoggingSheet: View {
    @Bindable var store: StoreOf<CalendarFeature>
    @State private var activeCategory: SymptomCategory = .physical
    @Namespace private var categoryNamespace


    private var selectedSymptoms: Set<String> {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return Set(store.loggedDays[key]?.symptoms ?? [])
    }

    private var selectedSymptomTypes: [SymptomType] {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return (store.loggedDays[key]?.symptoms ?? []).compactMap { SymptomType(rawValue: $0) }
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: store.selectedDate)
    }

    private var totalSelectedCount: Int {
        selectedSymptoms.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                summaryStrip
                categoryTabs
                symptomCarousel
            }

            if !selectedSymptoms.isEmpty {
                SymptomSaveButton(
                    isSaving: store.isSavingSymptoms,
                    isSaved: store.symptomsSaved,
                    totalSelected: totalSelectedCount,
                    onSave: {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        store.send(.saveSymptomsTapped, animation: .easeInOut(duration: 0.3))
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.appBalanced, value: selectedSymptoms.isEmpty)
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            HStack(alignment: .center) {
                Text("How are you feeling?")
                    .font(.raleway("Bold", size: 24, relativeTo: .title))
                    .foregroundStyle(DesignColors.text)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    store.send(.symptomSheetDismissed, animation: .spring(response: 0.35, dampingFraction: 0.9))
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.text)
                        .frame(width: 44, height: 44)
                        .background {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.85), Color.white.opacity(0.5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.9), Color.clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                                    .padding(2)
                                    .offset(y: -2)
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                        }
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Summary Strip

    @ViewBuilder
    private var summaryStrip: some View {
        if !selectedSymptomTypes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedSymptomTypes) { symptom in
                        SymptomSummaryPill(
                            symptom: symptom,
                            onRemove: {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                store.send(
                                    .symptomToggled(symptom),
                                    animation: .spring(response: 0.3, dampingFraction: 0.8)
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
            .transition(.opacity)
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(SymptomCategory.allCases, id: \.rawValue) { category in
                        SymptomCategoryTab(
                            category: category,
                            isActive: activeCategory == category,
                            selectedCount: category.symptoms.filter { selectedSymptoms.contains($0.rawValue) }.count,
                            namespace: categoryNamespace,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                withAnimation(.appBalanced) {
                                    activeCategory = category
                                }
                                withAnimation {
                                    proxy.scrollTo(category.rawValue, anchor: .center)
                                }
                            }
                        )
                        .id(category.rawValue)
                    }
                }
                .padding(4)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.65), Color.white.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Symptom Carousel

    private var symptomCarousel: some View {
        SymptomCategoryPage(
            category: activeCategory,
            selectedSymptoms: selectedSymptoms,
            onToggle: { symptom in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(
                    .symptomToggled(symptom),
                    animation: .spring(response: 0.3, dampingFraction: 0.8)
                )
            }
        )
    }
}

// MARK: - Symptom Summary Pill

struct SymptomSummaryPill: View {
    let symptom: SymptomType
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            symptomIcon(for: symptom, size: 14)
                .foregroundStyle(.white)
            Text(symptom.displayName)
                .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .padding(3)
                    .background {
                        Circle().fill(Color.white.opacity(0.25))
                    }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(DesignColors.accentSecondary)
                .shadow(color: DesignColors.accentSecondary.opacity(0.2), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Symptom Icon Helper

@ViewBuilder
func symptomIcon(for symptom: SymptomType, size: CGFloat) -> some View {
    if let customIcon = symptom.customIcon {
        Image(customIcon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    } else {
        Image(systemName: symptom.sfSymbol)
            .font(.system(size: size * 0.85, weight: .medium))
    }
}

// MARK: - Category Tab

struct SymptomCategoryTab: View {
    let category: SymptomCategory
    let isActive: Bool
    let selectedCount: Int
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 15, weight: .semibold))

                Text(category.rawValue)
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                    .lineLimit(1)

                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.raleway("Bold", size: 11, relativeTo: .caption2))
                        .foregroundStyle(isActive ? category.tintColor : .white)
                        .frame(width: 20, height: 20)
                        .background {
                            Circle().fill(isActive ? Color.white : category.tintColor)
                        }
                }
            }
            .foregroundStyle(isActive ? DesignColors.text : DesignColors.textSecondary.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if isActive {
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(2)
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), category.tintColor.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .matchedGeometryEffect(id: "activeTab", in: namespace)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Page

struct SymptomCategoryPage: View {
    let category: SymptomCategory
    let selectedSymptoms: Set<String>
    let onToggle: (SymptomType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(category.symptoms, id: \.rawValue) { symptom in
                    let isSelected = selectedSymptoms.contains(symptom.rawValue)
                    SymptomIconCard(
                        symptom: symptom,
                        isSelected: isSelected,
                        tintColor: category.tintColor,
                        onTap: { onToggle(symptom) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Save Button

struct SymptomSaveButton: View {
    let isSaving: Bool
    let isSaved: Bool
    let totalSelected: Int
    let onSave: () -> Void

    var body: some View {
        Button(action: onSave) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(buttonText)
                    .font(.raleway("Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSaved
                            ? AnyShapeStyle(DesignColors.statusSuccess)
                            : AnyShapeStyle(LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .shadow(
                        color: (isSaved ? DesignColors.statusSuccess : DesignColors.accentWarm).opacity(0.35),
                        radius: 16, x: 0, y: 6
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isSaving || isSaved)
    }

    private var buttonText: String {
        isSaved
            ? "Saved"
            : isSaving
                ? "Saving..."
                : "Save \(totalSelected) symptom\(totalSelected == 1 ? "" : "s")"
    }
}

// MARK: - Symptom Icon Card

struct SymptomIconCard: View {
    let symptom: SymptomType
    let isSelected: Bool
    let tintColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [tintColor.opacity(0.8), tintColor.opacity(0.55)]
                                    : [DesignColors.structure.opacity(0.1), DesignColors.structure.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.white.opacity(0.4) : DesignColors.structure.opacity(0.15),
                                    lineWidth: isSelected ? 1 : 0.5
                                )
                        }
                        .animation(.none, value: isSelected)

                    symptomIcon(for: symptom, size: 28)
                        .foregroundStyle(isSelected ? .white : DesignColors.accentWarm)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .background {
                                Circle()
                                    .fill(tintColor)
                                    .frame(width: 20, height: 20)
                            }
                            .offset(x: 22, y: -22)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(symptom.displayName)
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(isSelected ? DesignColors.text : DesignColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(height: 30)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
    }
}
