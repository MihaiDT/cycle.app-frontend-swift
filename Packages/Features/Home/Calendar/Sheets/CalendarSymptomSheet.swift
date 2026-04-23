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

