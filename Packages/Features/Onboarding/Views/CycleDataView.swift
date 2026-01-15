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

private struct RegularityCheckboxIcon: View {
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

// MARK: - Backend API Models

/// Cycle regularity options matching backend enum
public enum CycleRegularity: String, CaseIterable, Identifiable, Sendable {
    case regular = "regular"
    case somewhatRegular = "somewhat_regular"
    case irregular = "irregular"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .somewhatRegular: return "Somewhat Regular"
        case .irregular: return "Irregular"
        }
    }

    var description: String {
        switch self {
        case .regular: return "My cycle is predictable"
        case .somewhatRegular: return "Varies by a few days"
        case .irregular: return "Hard to predict"
        }
    }

    var emoji: String {
        switch self {
        case .regular: return "📅"
        case .somewhatRegular: return "📆"
        case .irregular: return "❓"
        }
    }
}

/// Symptom types matching backend enum
public enum SymptomType: String, CaseIterable, Identifiable, Sendable {
    // Physical symptoms
    case cramping = "cramping"
    case headache = "headache"
    case backPain = "back_pain"
    case bloating = "bloating"
    case breastTenderness = "breast_tenderness"
    case nausea = "nausea"
    case acne = "acne"
    case dizziness = "dizziness"
    case hotFlashes = "hot_flashes"
    case jointPain = "joint_pain"
    case allGood = "all_good"
    case fever = "fever"
    case lowBloodPressure = "low_blood_pressure"
    case vaginalDryness = "vaginal_dryness"
    case vaginalItching = "vaginal_itching"
    case vaginalPain = "vaginal_pain"

    // Digestive symptoms
    case constipation = "constipation"
    case diarrhea = "diarrhea"
    case appetiteChanges = "appetite_changes"
    case cravings = "cravings"
    case hunger = "hunger"

    // Mood & Emotional symptoms
    case calm = "calm"
    case happy = "happy"
    case sensitive = "sensitive"
    case sad = "sad"
    case apathetic = "apathetic"
    case tired = "tired"
    case angry = "angry"
    case selfCritical = "self_critical"
    case lively = "lively"
    case motivated = "motivated"
    case anxious = "anxious"
    case confident = "confident"
    case irritable = "irritable"
    case emotional = "emotional"
    case moodSwings = "mood_swings"

    // Energy & Stress
    case lowEnergy = "low_energy"
    case normalEnergy = "normal_energy"
    case highEnergy = "high_energy"
    case noStress = "no_stress"
    case manageableStress = "manageable_stress"
    case intenseStress = "intense_stress"

    // Sleep
    case peacefulSleep = "peaceful_sleep"
    case difficultyFallingAsleep = "difficulty_falling_asleep"
    case restlessSleep = "restless_sleep"
    case insomnia = "insomnia"

    // Skin
    case normalSkin = "normal_skin"
    case drySkin = "dry_skin"
    case oilySkin = "oily_skin"
    case skinBreakouts = "skin_breakouts"
    case itchySkin = "itchy_skin"

    // Hair
    case normalHair = "normal_hair"
    case shinyHair = "shiny_hair"
    case oilyHair = "oily_hair"
    case dryHair = "dry_hair"
    case sensitiveSkin = "sensitive_skin"
    case hairLoss = "hair_loss"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        // Physical
        case .cramping: return "Cramps"
        case .headache: return "Headaches"
        case .backPain: return "Back Pain"
        case .bloating: return "Bloating"
        case .breastTenderness: return "Breast Tenderness"
        case .nausea: return "Nausea"
        case .acne: return "Acne"
        case .dizziness: return "Dizziness"
        case .hotFlashes: return "Hot Flashes"
        case .jointPain: return "Joint Pain"
        case .allGood: return "All Good"
        case .fever: return "Fever"
        case .lowBloodPressure: return "Low Blood Pressure"
        case .vaginalDryness: return "Vaginal Dryness"
        case .vaginalItching: return "Vaginal Itching"
        case .vaginalPain: return "Vaginal Pain"
        // Digestive
        case .constipation: return "Constipation"
        case .diarrhea: return "Diarrhea"
        case .appetiteChanges: return "Appetite Changes"
        case .cravings: return "Cravings"
        case .hunger: return "Increased Hunger"
        // Mood
        case .calm: return "Calm"
        case .happy: return "Happy"
        case .sensitive: return "Sensitive"
        case .sad: return "Sad"
        case .apathetic: return "Apathetic"
        case .tired: return "Tired"
        case .angry: return "Angry"
        case .selfCritical: return "Self-Critical"
        case .lively: return "Lively"
        case .motivated: return "Motivated"
        case .anxious: return "Anxious"
        case .confident: return "Confident"
        case .irritable: return "Irritable"
        case .emotional: return "Emotional"
        case .moodSwings: return "Mood Swings"
        // Energy & Stress
        case .lowEnergy: return "Low Energy"
        case .normalEnergy: return "Normal Energy"
        case .highEnergy: return "High Energy"
        case .noStress: return "No Stress"
        case .manageableStress: return "Manageable"
        case .intenseStress: return "Intense Stress"
        // Sleep
        case .peacefulSleep: return "Peaceful Sleep"
        case .difficultyFallingAsleep: return "Hard to Fall Asleep"
        case .restlessSleep: return "Restless Sleep"
        case .insomnia: return "Insomnia"
        // Skin
        case .normalSkin: return "Normal Skin"
        case .drySkin: return "Dry Skin"
        case .oilySkin: return "Oily Skin"
        case .skinBreakouts: return "Breakouts"
        case .itchySkin: return "Itchy Skin"
        // Hair
        case .normalHair: return "Normal Hair"
        case .shinyHair: return "Shiny Hair"
        case .oilyHair: return "Oily Hair"
        case .dryHair: return "Dry Hair"
        case .sensitiveSkin: return "Sensitive Scalp"
        case .hairLoss: return "Hair Loss"
        }
    }

    /// Returns the custom icon name from Assets (Figma icons) or nil for SF Symbol fallback
    var customIcon: String? {
        switch self {
        // Mood - have custom Figma icons
        case .calm: return "mood_calm"
        case .happy: return "mood_happy"
        case .sensitive: return "mood_sensitive"
        case .sad: return "mood_sad"
        case .apathetic: return "mood_apathetic"
        case .tired: return "mood_tired"
        case .angry: return "mood_angry"
        case .selfCritical: return "mood_selfcritical"
        case .lively: return "mood_lively"
        case .motivated: return "mood_motivated"
        case .anxious: return "mood_anxious"
        case .confident: return "mood_confident"
        case .irritable: return "mood_irritable"
        case .emotional: return "mood_emotional"
        case .moodSwings: return "mood_swings"
        // Energy & Stress - have custom Figma icons
        case .lowEnergy: return "energy_low"
        case .normalEnergy: return "energy_normal"
        case .highEnergy: return "energy_high"
        case .noStress: return "stress_zero"
        case .manageableStress: return "stress_manageable"
        case .intenseStress: return "stress_intense"
        // Sleep - have custom Figma icons
        case .peacefulSleep: return "sleep_peaceful"
        case .difficultyFallingAsleep: return "sleep_difficulty"
        case .restlessSleep: return "sleep_restless"
        case .insomnia: return "sleep_insomnia"
        // Skin - have custom Figma icons
        case .normalSkin: return "skin_normal"
        case .drySkin: return "skin_dry"
        case .oilySkin: return "skin_oily"
        case .skinBreakouts: return "skin_acne"
        case .itchySkin: return "skin_itchy"
        // Hair - have custom Figma icons
        case .normalHair: return "hair_normal"
        case .shinyHair: return "hair_shiny"
        case .oilyHair: return "hair_oily"
        case .dryHair: return "hair_dry"
        case .sensitiveSkin: return "hair_sensitive"
        case .hairLoss: return "hair_loss"
        // Physical - have custom icons
        case .cramping: return "physical_cramps"
        case .headache: return "physical_headache"
        case .backPain: return "physical_backpain"
        case .bloating: return "physical_bloating"
        case .breastTenderness: return "physical_breast"
        case .nausea: return "physical_nausea"
        case .acne: return "physical_acne"
        case .dizziness: return "physical_dizziness"
        case .hotFlashes: return "physical_hotflash"
        case .jointPain: return "physical_joint"
        case .allGood: return "physical_allgood"
        case .fever: return "physical_fever"
        case .lowBloodPressure: return "physical_lowbloodpressure"
        case .vaginalDryness: return "physical_vaginaldryness"
        case .vaginalItching: return "physical_vaginalitching"
        case .vaginalPain: return "physical_vaginalpain"
        // Digestive - have custom icons
        case .constipation: return "digestive_constipation"
        case .diarrhea: return "digestive_diarrhea"
        case .appetiteChanges: return "digestive_appetite"
        case .cravings: return "digestive_cravings"
        case .hunger: return "digestive_hunger"
        }
    }

    /// SF Symbol fallback for symptoms without custom icons
    var sfSymbol: String {
        switch self {
        // Physical
        case .cramping: return "bandage"
        case .headache: return "brain.head.profile"
        case .backPain: return "figure.stand"
        case .bloating: return "bubble.middle.bottom"
        case .breastTenderness: return "heart"
        case .nausea: return "face.smiling.inverse"
        case .acne: return "circle.hexagonpath"
        case .dizziness: return "tornado"
        case .hotFlashes: return "thermometer.high"
        case .jointPain: return "figure.walk"
        case .allGood: return "checkmark.circle"
        case .fever: return "thermometer"
        case .lowBloodPressure: return "arrow.down.heart"
        case .vaginalDryness: return "drop"
        case .vaginalItching: return "hand.raised"
        case .vaginalPain: return "exclamationmark.circle"
        // Digestive
        case .constipation: return "arrow.down.to.line"
        case .diarrhea: return "arrow.up.to.line"
        case .appetiteChanges: return "fork.knife"
        case .cravings: return "birthday.cake"
        case .hunger: return "flame"
        // Others - fallback
        default: return "circle"
        }
    }

    /// Group symptoms by category for better UX
    static var physicalSymptoms: [SymptomType] {
        [
            .allGood, .cramping, .headache, .backPain, .bloating, .breastTenderness, .nausea, .acne, .dizziness, .hotFlashes,
            .jointPain, .fever, .lowBloodPressure, .vaginalDryness, .vaginalItching, .vaginalPain,
        ]
    }

    static var digestiveSymptoms: [SymptomType] {
        [.constipation, .diarrhea, .appetiteChanges, .cravings, .hunger]
    }

    static var moodSymptoms: [SymptomType] {
        [
            .calm, .happy, .sensitive, .sad, .apathetic, .tired, .angry, .selfCritical, .lively, .motivated, .anxious,
            .confident, .irritable, .emotional, .moodSwings,
        ]
    }

    static var energySymptoms: [SymptomType] {
        [.lowEnergy, .normalEnergy, .highEnergy, .noStress, .manageableStress, .intenseStress]
    }

    static var sleepSymptoms: [SymptomType] {
        [.peacefulSleep, .difficultyFallingAsleep, .restlessSleep, .insomnia]
    }

    static var skinSymptoms: [SymptomType] {
        [.normalSkin, .drySkin, .oilySkin, .skinBreakouts, .itchySkin]
    }

    static var hairSymptoms: [SymptomType] {
        [.normalHair, .shinyHair, .oilyHair, .dryHair, .sensitiveSkin, .hairLoss]
    }

    // Legacy groupings for backward compatibility
    static var emotionalSymptoms: [SymptomType] {
        moodSymptoms
    }
}

/// Contraception types matching backend enum
public enum ContraceptionType: String, CaseIterable, Identifiable, Sendable {
    case pill = "pill"
    case iud = "iud"
    case implant = "implant"
    case patch = "patch"
    case ring = "ring"
    case injection = "injection"
    case other = "other"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill: return "Birth Control Pill"
        case .iud: return "IUD"
        case .implant: return "Implant"
        case .patch: return "Patch"
        case .ring: return "Vaginal Ring"
        case .injection: return "Injection"
        case .other: return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .pill: return "💊"
        case .iud: return "🔷"
        case .implant: return "💉"
        case .patch: return "🩹"
        case .ring: return "⭕"
        case .injection: return "💉"
        case .other: return "➕"
        }
    }
}

// MARK: - Cycle Data View

public struct CycleDataView: View {
    // Required fields (matching backend API)
    @Binding public var lastPeriodDate: Date
    @Binding public var cycleDuration: Int  // avgCycleLength (21-40)
    @Binding public var periodDuration: Int  // avgBleedingDays (2-10)
    @Binding public var cycleRegularity: CycleRegularity

    // Optional fields
    @Binding public var flowIntensity: Int  // 1-5 scale
    @Binding public var selectedSymptoms: Set<SymptomType>
    @Binding public var usesContraception: Bool
    @Binding public var contraceptionType: ContraceptionType?

    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    private let calendar = Calendar.current

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    public init(
        lastPeriodDate: Binding<Date>,
        cycleDuration: Binding<Int>,
        periodDuration: Binding<Int>,
        cycleRegularity: Binding<CycleRegularity>,
        flowIntensity: Binding<Int>,
        selectedSymptoms: Binding<Set<SymptomType>>,
        usesContraception: Binding<Bool>,
        contraceptionType: Binding<ContraceptionType?>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._lastPeriodDate = lastPeriodDate
        self._cycleDuration = cycleDuration
        self._periodDuration = periodDuration
        self._cycleRegularity = cycleRegularity
        self._flowIntensity = flowIntensity
        self._selectedSymptoms = selectedSymptoms
        self._usesContraception = usesContraception
        self._contraceptionType = contraceptionType
        self.onNext = onNext
        self.onBack = onBack
    }

    // Current page state (6 pages total)
    @State private var currentPage = 0
    private let totalPages = 6

    public var body: some View {
        OnboardingLayout(
            currentStep: 3 + currentPage,  // Steps 3-8
            totalSteps: 8,
            onBack: {
                if currentPage > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                } else {
                    onBack?()
                }
            },
            onNext: {
                if currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                } else {
                    onNext()
                }
            },
            nextButtonEnabled: true
        ) {
            TabView(selection: $currentPage) {
                // Page 0: Calendar
                InlinePeriodCalendarPage(
                    selectedDate: $lastPeriodDate,
                    periodDuration: $periodDuration
                )
                .tag(0)

                // Page 1: Cycle & Period Duration
                CycleDataPage(
                    title: "How long is\nyour cycle?",
                    subtitle: "Typical cycles are 21-40 days"
                ) {
                    VStack(spacing: 24) {
                        DurationStepper(
                            label: "Cycle Length",
                            value: $cycleDuration,
                            range: 21...40,
                            unit: "days"
                        )

                        DurationStepper(
                            label: "Period Length",
                            value: $periodDuration,
                            range: 2...10,
                            unit: "days"
                        )
                    }
                    .padding(.horizontal, 32)
                }
                .tag(1)

                // Page 2: Cycle Regularity
                CycleDataPage(
                    title: "How regular is\nyour cycle?",
                    subtitle: "This helps us predict better"
                ) {
                    VStack(spacing: 12) {
                        ForEach(CycleRegularity.allCases) { regularity in
                            RegularityOptionButton(
                                regularity: regularity,
                                isSelected: cycleRegularity == regularity
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    cycleRegularity = regularity
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .tag(2)

                // Page 3: Flow Intensity
                CycleDataPage(
                    title: "How would you\ndescribe your flow?",
                    subtitle: "Your typical period intensity"
                ) {
                    FlowIntensitySelector(intensity: $flowIntensity)
                        .padding(.horizontal, 32)
                }
                .tag(3)

                // Page 4: Symptoms
                CycleDataPage(
                    title: "What symptoms do\nyou typically experience?",
                    subtitle: "Select all that apply"
                ) {
                    InlineSymptomsSelector(selectedSymptoms: $selectedSymptoms)
                }
                .tag(4)

                // Page 5: Contraception
                CycleDataPage(
                    title: "Do you use\ncontraception?",
                    subtitle: "Optional but helps with accuracy"
                ) {
                    InlineContraceptionSelector(
                        usesContraception: $usesContraception,
                        contraceptionType: $contraceptionType
                    )
                    .padding(.horizontal, 32)
                }
                .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
        }
    }
}

// MARK: - Cycle Data Page Container

private struct CycleDataPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                Text(title)
                    .font(.custom("Raleway-Bold", size: 26))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text(subtitle)
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 32)

                content

                Spacer().frame(height: 120)
            }
        }
    }
}

// MARK: - Inline Period Calendar Page

private struct InlinePeriodCalendarPage: View {
    @Binding var selectedDate: Date
    @Binding var periodDuration: Int

    private let calendar = Calendar.current

    // Multiple periods support
    struct Period: Identifiable, Equatable {
        let id = UUID()
        var start: Date
        var end: Date

        var duration: Int {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return days + 1
        }
    }

    @State private var periods: [Period] = []
    @State private var currentStart: Date? = nil
    @State private var currentEnd: Date? = nil

    enum TutorialStep {
        case selectStart
        case selectEnd
        case complete
    }
    @State private var tutorialStep: TutorialStep = .selectStart
    @State private var showTutorialPopup: Bool = true
    @State private var hasSeenTutorial: Bool = false
    @State private var pulseAnimation: Bool = false

    // Generate 6 months back + current month
    private var months: [Date] {
        var dates: [Date] = []
        let today = Date()
        for i in stride(from: -6, through: 0, by: 1) {
            if let date = calendar.date(byAdding: .month, value: i, to: today) {
                dates.append(calendar.startOfMonth(for: date))
            }
        }
        return dates
    }

    private var allPeriodDates: Set<Date> {
        var dates: Set<Date> = []
        for period in periods {
            var current = period.start
            while current <= period.end {
                dates.insert(calendar.startOfDay(for: current))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        if let start = currentStart {
            if let end = currentEnd {
                var current = start
                while current <= end {
                    dates.insert(calendar.startOfDay(for: current))
                    guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                    current = next
                }
            } else {
                dates.insert(calendar.startOfDay(for: start))
            }
        }
        return dates
    }

    private var currentSelectionDates: Set<Date> {
        var dates: Set<Date> = []
        guard let start = currentStart else { return dates }
        guard let end = currentEnd else {
            dates.insert(calendar.startOfDay(for: start))
            return dates
        }
        var current = start
        while current <= end {
            dates.insert(calendar.startOfDay(for: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private var currentDuration: Int {
        guard let start = currentStart, let end = currentEnd else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }

    private func confirmCurrentPeriod() {
        guard let start = currentStart, let end = currentEnd else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            periods.append(Period(start: start, end: end))
            currentStart = nil
            currentEnd = nil
            tutorialStep = .selectStart
            showTutorialPopup = false  // Don't show tutorial again
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func handleDayTap(_ date: Date) {
        let tappedDate = calendar.startOfDay(for: date)

        // Check if tapping on an existing period to delete it
        if let periodIndex = periods.firstIndex(where: { period in
            var current = period.start
            while current <= period.end {
                if calendar.isDate(current, inSameDayAs: tappedDate) {
                    return true
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return false
        }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                periods.remove(at: periodIndex)
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            switch tutorialStep {
            case .selectStart:
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
                if !hasSeenTutorial {
                    showTutorialPopup = true
                }

            case .selectEnd:
                if let start = currentStart {
                    if tappedDate < start {
                        currentEnd = start
                        currentStart = tappedDate
                    } else {
                        currentEnd = tappedDate
                    }
                    tutorialStep = .complete
                    if !hasSeenTutorial {
                        showTutorialPopup = true
                        hasSeenTutorial = true
                    }
                    // Auto-save to bindings
                    selectedDate = currentStart ?? tappedDate
                    periodDuration = min(max(currentDuration, 2), 10)
                }

            case .complete:
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
                showTutorialPopup = false  // Don't show tutorial again
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func getSubtitleText() -> String {
        let totalPeriods = periods.count + (currentEnd != nil ? 1 : 0)

        switch tutorialStep {
        case .selectStart:
            if periods.isEmpty {
                return "Tap the first day of your period"
            } else {
                return "\(periods.count) period\(periods.count == 1 ? "" : "s") added • Add more?"
            }
        case .selectEnd:
            return "Now tap the last day"
        case .complete:
            return "\(currentDuration) days selected"
        }
    }

    private var tutorialTitle: String {
        switch tutorialStep {
        case .selectStart: return "Step 1"
        case .selectEnd: return "Step 2"
        case .complete: return "Perfect!"
        }
    }

    private var tutorialMessage: String {
        switch tutorialStep {
        case .selectStart: return "Tap the first day of your last period"
        case .selectEnd: return "Now tap the last day of your period"
        case .complete: return "Your period is \(currentDuration) days. You can add more periods or continue."
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                Text("When did your\nlast period start?")
                    .font(.custom("Raleway-Bold", size: 26))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text(getSubtitleText())
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(tutorialStep == .complete ? DesignColors.accent : DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: tutorialStep)

                // Period info and Add button
                HStack {
                    Spacer()

                    Button {
                        confirmCurrentPeriod()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add & mark another")
                                .font(.custom("Raleway-SemiBold", size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(DesignColors.accent)
                        )
                    }

                    Spacer()
                }
                .padding(.top, 12)
                .opacity(tutorialStep == .complete && currentStart != nil && currentEnd != nil ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: tutorialStep)

                // Saved periods count
                Text("\(periods.count) period\(periods.count == 1 ? "" : "s") saved")
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundColor(DesignColors.text.opacity(0.6))
                    .padding(.top, 8)
                    .opacity(periods.isEmpty ? 0 : 1)

                Spacer().frame(height: 16)

                // Scrollable calendar container
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 32) {
                            ForEach(months, id: \.self) { month in
                                InlineMonthView(
                                    month: month,
                                    periodStart: currentStart,
                                    periodEnd: currentEnd,
                                    allPeriodDates: allPeriodDates,
                                    currentSelectionDates: currentSelectionDates,
                                    savedPeriods: periods,
                                    onDayTap: handleDayTap
                                )
                                .id(month)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                    }
                    .onAppear {
                        let currentMonth = calendar.startOfMonth(for: Date())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentMonth, anchor: .center)
                            }
                        }
                    }
                }
            }

            // Tutorial popup overlay
            if showTutorialPopup && tutorialStep != .complete {
                Color.black.opacity(0.001)  // Invisible tap target
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTutorialPopup = false
                        }
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Step indicator - using darker colors for accessibility (WCAG contrast)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    tutorialStep == .selectStart
                                        ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 8, height: 8)

                            Rectangle()
                                .fill(
                                    tutorialStep == .selectEnd ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 20, height: 2)

                            Circle()
                                .fill(
                                    tutorialStep == .selectEnd ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 8, height: 8)
                        }

                        Text(tutorialTitle)
                            .font(.custom("Raleway-Bold", size: 18))
                            .foregroundColor(DesignColors.text)

                        Text(tutorialMessage)
                            .font(.custom("Raleway-Regular", size: 15))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            .multilineTextAlignment(.center)

                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignColors.accentSecondary)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .opacity(pulseAnimation ? 0.85 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                            .onAppear {
                                pulseAnimation = true
                            }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showTutorialPopup = false
                            }
                        } label: {
                            Text("Got it")
                                .font(.custom("Raleway-SemiBold", size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(DesignColors.accentWarm)
                                )
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Completion popup
            if showTutorialPopup && tutorialStep == .complete && periods.isEmpty && !hasSeenTutorial {
                Color.black.opacity(0.001)  // Invisible tap target
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTutorialPopup = false
                        }
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)

                        Text("Period marked!")
                            .font(.custom("Raleway-Bold", size: 20))
                            .foregroundColor(DesignColors.text)

                        Text("\(currentDuration) days selected")
                            .font(.custom("Raleway-Regular", size: 15))
                            .foregroundColor(DesignColors.text.opacity(0.7))

                        Text("Do you remember previous periods?")
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundColor(DesignColors.text.opacity(0.6))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button {
                                confirmCurrentPeriod()
                                withAnimation {
                                    showTutorialPopup = false
                                }
                            } label: {
                                Text("Add more")
                                    .font(.custom("Raleway-SemiBold", size: 15))
                                    .foregroundColor(DesignColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .strokeBorder(DesignColors.accent, lineWidth: 1.5)
                                    )
                            }

                            Button {
                                withAnimation {
                                    showTutorialPopup = false
                                }
                            } label: {
                                Text("Continue")
                                    .font(.custom("Raleway-SemiBold", size: 15))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(DesignColors.accent)
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Inline Month View

private struct InlineMonthView: View {
    let month: Date
    let periodStart: Date?
    let periodEnd: Date?
    let allPeriodDates: Set<Date>
    let currentSelectionDates: Set<Date>
    let savedPeriods: [InlinePeriodCalendarPage.Period]
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func isInPeriod(_ date: Date) -> Bool {
        allPeriodDates.contains(calendar.startOfDay(for: date))
    }

    private func isCurrentSelection(_ date: Date) -> Bool {
        currentSelectionDates.contains(calendar.startOfDay(for: date))
    }

    private func isStartDate(_ date: Date) -> Bool {
        if let start = periodStart, calendar.isDate(date, inSameDayAs: start) {
            return true
        }
        // Check saved periods
        for period in savedPeriods {
            if calendar.isDate(date, inSameDayAs: period.start) {
                return true
            }
        }
        return false
    }

    private func isEndDate(_ date: Date) -> Bool {
        if let end = periodEnd, calendar.isDate(date, inSameDayAs: end) {
            return true
        }
        // Check saved periods
        for period in savedPeriods {
            if calendar.isDate(date, inSameDayAs: period.end) {
                return true
            }
        }
        return false
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        date > Date()
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month header
            Text(monthName)
                .font(.custom("Raleway-SemiBold", size: 18))
                .foregroundColor(DesignColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.custom("Raleway-Medium", size: 12))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(height: 24)
                }
            }

            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        InlineDayCell(
                            date: date,
                            isInPeriod: isInPeriod(date),
                            isCurrentSelection: isCurrentSelection(date),
                            isStartDate: isStartDate(date),
                            isEndDate: isEndDate(date),
                            isToday: isToday(date),
                            isFuture: isFuture(date),
                            onTap: { onDayTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }
}

private struct InlineDayCell: View {
    let date: Date
    let isInPeriod: Bool
    let isCurrentSelection: Bool
    let isStartDate: Bool
    let isEndDate: Bool
    let isToday: Bool
    let isFuture: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: {
            if !isFuture {
                onTap()
            }
        }) {
            VStack(spacing: 2) {
                ZStack {
                    // Period highlight background
                    if isInPeriod {
                        if isStartDate || isEndDate {
                            Circle()
                                .fill(isCurrentSelection ? DesignColors.accentWarm : DesignColors.roseTaupe)
                        } else {
                            // Middle days - use circles
                            Circle()
                                .fill(
                                    isCurrentSelection
                                        ? DesignColors.accentWarm.opacity(0.4) : DesignColors.roseTaupeLight
                                )
                        }
                    } else if isToday {
                        Circle()
                            .strokeBorder(DesignColors.accentWarm, lineWidth: 1.5)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.custom(isStartDate || isEndDate ? "Raleway-Bold" : "Raleway-Medium", size: 16))
                        .foregroundColor(dayTextColor)
                }
                .frame(width: 40, height: 40)

                // "Today" label
                if isToday {
                    Text("today")
                        .font(.custom("Raleway-Medium", size: 9))
                        .foregroundColor(DesignColors.accentWarm)
                }
            }
        }
        .disabled(isFuture)
        .buttonStyle(.plain)
    }

    private var dayTextColor: Color {
        if isFuture {
            return DesignColors.text.opacity(0.3)
        } else if isStartDate || isEndDate {
            return .white
        } else if isInPeriod {
            return DesignColors.text
        } else {
            return DesignColors.text
        }
    }
}

// MARK: - Duration Stepper

private struct DurationStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    
    @State private var isIncrementing: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.custom("Raleway-SemiBold", size: 16))
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

                VStack(spacing: 4) {
                    Text("\(value)")
                        .font(.custom("Raleway-Bold", size: 48))
                        .foregroundColor(DesignColors.text)
                        .contentTransition(.numericText(countsDown: !isIncrementing))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
                    Text(unit)
                        .font(.custom("Raleway-Regular", size: 14))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }
                .frame(width: 100)

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

private struct RegularityOptionButton: View {
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
                        .font(.custom("Raleway-SemiBold", size: 17))
                        .foregroundColor(DesignColors.text)

                    // Animated subtitle
                    Text(regularity.description)
                        .font(.custom("Raleway-Regular", size: 12))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSelected)
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

// MARK: - Inline Period Calendar

private struct InlinePeriodCalendar: View {
    @Binding var selectedDate: Date
    let periodDuration: Int

    private let calendar = Calendar.current
    @State private var displayedMonth = Date()

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func isInPeriod(_ date: Date) -> Bool {
        guard
            let startOfSelected = calendar.date(
                from: calendar.dateComponents([.year, .month, .day], from: selectedDate)
            ),
            let startOfDate = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date))
        else {
            return false
        }
        let daysDiff = calendar.dateComponents([.day], from: startOfSelected, to: startOfDate).day ?? 0
        return daysDiff >= 0 && daysDiff < periodDuration
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        date > Date()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: {
                    withAnimation {
                        displayedMonth =
                            calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                }

                Spacer()

                Text(monthFormatter.string(from: displayedMonth))
                    .font(.custom("Raleway-SemiBold", size: 18))
                    .foregroundColor(DesignColors.text)

                Spacer()

                Button(action: {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                }
            }
            .padding(.horizontal, 8)

            // Day headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.custom("Raleway-SemiBold", size: 12))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(height: 30)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayButton(
                            date: date,
                            isSelected: isSelected(date),
                            isInPeriod: isInPeriod(date),
                            isToday: isToday(date),
                            isDisabled: isFuture(date)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal, 24)
        .onAppear {
            displayedMonth = selectedDate
        }
    }
}

private struct CalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isInPeriod: Bool
    let isToday: Bool
    let isDisabled: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            Text("\(calendar.component(.day, from: date))")
                .font(.custom(isSelected ? "Raleway-Bold" : "Raleway-Medium", size: 16))
                .foregroundColor(textColor)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .fill(DesignColors.accent)
                    } else if isInPeriod {
                        Circle()
                            .fill(DesignColors.periodPinkLight)
                    } else if isToday {
                        Circle()
                            .strokeBorder(DesignColors.accent, lineWidth: 1.5)
                    }
                }
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isDisabled {
            return DesignColors.text.opacity(0.3)
        } else if isSelected {
            return .white
        } else if isInPeriod {
            return DesignColors.text
        } else {
            return DesignColors.text
        }
    }
}

// MARK: - Inline Symptoms Selector

private struct InlineSymptomsSelector: View {
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
                            .font(.custom("Raleway-SemiBold", size: 14))
                            .foregroundColor(DesignColors.text.opacity(0.6))
                            .padding(.horizontal, 32)

                        FlowLayout(spacing: 10) {
                            ForEach(symptoms) { symptom in
                                SymptomChip(
                                    symptom: symptom,
                                    isSelected: selectedSymptoms.contains(symptom)
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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

private struct InlineContraceptionSelector: View {
    @Binding var usesContraception: Bool
    @Binding var contraceptionType: ContraceptionType?

    var body: some View {
        VStack(spacing: 16) {
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
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundColor(DesignColors.text.opacity(0.6))

                HStack(spacing: 4) {
                    Text(value)
                        .font(.custom("Raleway-Bold", size: 24))
                        .foregroundColor(accentColor)

                    Text(unit)
                        .font(.custom("Raleway-Regular", size: 14))
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
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(DesignColors.text.opacity(0.6))

                    Text(value)
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundColor(DesignColors.text)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
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

private struct FlowIntensitySelector: View {
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
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(DesignColors.text.opacity(0.6))

                    Text(intensityLabel)
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundColor(DesignColors.text)
                }

                Spacer()
            }

            // Intensity dots
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { level in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                } else {
                    Text(symptomNames)
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(DesignColors.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
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
                        .font(.custom("Raleway-SemiBold", size: 15))
                        .foregroundColor(DesignColors.text)
                } else if usesContraception {
                    Text("Using contraception")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(DesignColors.text.opacity(0.8))
                } else {
                    Text("Not using contraception")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
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

// MARK: - Period Calendar Sheet (Flo-style)

struct PeriodCalendarSheet: View {
    @Binding var selectedDate: Date
    @Binding var periodDuration: Int
    @Binding var isPresented: Bool

    // Multiple periods support
    struct Period: Identifiable, Equatable {
        let id = UUID()
        var start: Date
        var end: Date

        var duration: Int {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return days + 1
        }
    }

    @State private var periods: [Period] = []

    // Current selection state
    @State private var currentStart: Date? = nil
    @State private var currentEnd: Date? = nil

    // Tutorial steps
    enum TutorialStep {
        case selectStart
        case selectEnd
        case complete
    }
    @State private var tutorialStep: TutorialStep = .selectStart
    @State private var hasSeenTutorial: Bool = false
    @State private var showTutorialPopup: Bool = true
    @State private var pulseAnimation: Bool = false
    @State private var hasSaved: Bool = false
    @State private var showAddMorePrompt: Bool = false

    private let calendar = Calendar.current

    init(selectedDate: Binding<Date>, periodDuration: Binding<Int>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._periodDuration = periodDuration
        self._isPresented = isPresented
    }

    // Generate 6 months back + current month
    private var months: [Date] {
        var dates: [Date] = []
        let today = Date()
        for i in stride(from: -6, through: 0, by: 1) {
            if let date = calendar.date(byAdding: .month, value: i, to: today) {
                dates.append(calendar.startOfMonth(for: date))
            }
        }
        return dates
    }

    // All period dates including saved periods and current selection
    private var allPeriodDates: Set<Date> {
        var dates: Set<Date> = []

        // Add all saved periods
        for period in periods {
            var current = period.start
            while current <= period.end {
                dates.insert(calendar.startOfDay(for: current))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }

        // Add current selection
        if let start = currentStart {
            if let end = currentEnd {
                var current = start
                while current <= end {
                    dates.insert(calendar.startOfDay(for: current))
                    guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                    current = next
                }
            } else {
                dates.insert(calendar.startOfDay(for: start))
            }
        }

        return dates
    }

    // Current selection dates only
    private var currentSelectionDates: Set<Date> {
        var dates: Set<Date> = []
        guard let start = currentStart else { return dates }
        guard let end = currentEnd else {
            dates.insert(calendar.startOfDay(for: start))
            return dates
        }

        var current = start
        while current <= end {
            dates.insert(calendar.startOfDay(for: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private var currentDuration: Int {
        guard let start = currentStart, let end = currentEnd else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }

    private var canSave: Bool {
        (currentStart != nil && currentEnd != nil && currentDuration >= 1) || !periods.isEmpty
    }

    private var mostRecentPeriod: Period? {
        periods.max(by: { $0.start < $1.start })
    }

    private func handleDayTap(_ date: Date) {
        let tappedDate = calendar.startOfDay(for: date)

        // Check if tapping on an existing period to delete it
        if let periodIndex = periods.firstIndex(where: { period in
            var current = period.start
            while current <= period.end {
                if calendar.isDate(current, inSameDayAs: tappedDate) {
                    return true
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return false
        }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                periods.remove(at: periodIndex)
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            switch tutorialStep {
            case .selectStart:
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
                if !hasSeenTutorial {
                    showTutorialPopup = true
                }

            case .selectEnd:
                if let start = currentStart {
                    if tappedDate < start {
                        currentEnd = start
                        currentStart = tappedDate
                    } else {
                        currentEnd = tappedDate
                    }
                    tutorialStep = .complete
                    if !hasSeenTutorial {
                        showTutorialPopup = true
                        hasSeenTutorial = true
                    }
                }

            case .complete:
                // Start new selection
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func confirmCurrentPeriod() {
        guard let start = currentStart, let end = currentEnd else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            periods.append(Period(start: start, end: end))
            currentStart = nil
            currentEnd = nil
            tutorialStep = .selectStart
            showAddMorePrompt = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func saveSelection() {
        // Add current selection to periods if complete
        if let start = currentStart, let end = currentEnd {
            periods.append(Period(start: start, end: end))
        }

        // Use most recent period for the binding
        if let recent = periods.max(by: { $0.start < $1.start }) {
            selectedDate = recent.start
            periodDuration = min(max(recent.duration, 2), 10)
        }

        hasSaved = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTutorialPopup = false
            showAddMorePrompt = false
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func closeSheet() {
        // Auto-save when closing
        if let start = currentStart, let end = currentEnd {
            periods.append(Period(start: start, end: end))
        }

        // Update bindings with most recent period
        if let recent = periods.max(by: { $0.start < $1.start }) {
            selectedDate = recent.start
            periodDuration = min(max(recent.duration, 2), 10)
        }

        isPresented = false
    }

    private func getSubtitleText() -> String {
        let totalPeriods = periods.count + (currentEnd != nil ? 1 : 0)

        if hasSaved {
            if totalPeriods > 0 {
                return "\(totalPeriods) period\(totalPeriods == 1 ? "" : "s") marked • Tap to add more"
            }
            return "Tap to mark your period days"
        } else {
            switch tutorialStep {
            case .selectStart:
                if periods.isEmpty {
                    return "Tap to mark your period days"
                } else {
                    return "\(periods.count) period\(periods.count == 1 ? "" : "s") added • Add more?"
                }
            case .selectEnd:
                return "Now tap the last day"
            case .complete:
                return "\(currentDuration) days selected"
            }
        }
    }

    private var tutorialTitle: String {
        switch tutorialStep {
        case .selectStart: return "Step 1"
        case .selectEnd: return "Step 2"
        case .complete: return "Perfect!"
        }
    }

    private var tutorialMessage: String {
        switch tutorialStep {
        case .selectStart: return "Tap the first day of your last period"
        case .selectEnd: return "Now tap the last day of your period"
        case .complete: return "Your period is \(currentDuration) days. Tap Done to save."
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom Header
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Header content
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(periods.isEmpty && currentStart == nil ? "Select your period" : "Your periods")
                                .font(.custom("Raleway-Bold", size: 20))
                                .foregroundColor(DesignColors.text)

                            Text(getSubtitleText())
                                .font(.custom("Raleway-Regular", size: 14))
                                .foregroundColor(DesignColors.text.opacity(0.6))
                        }

                        Spacer()

                        // Close button - always visible
                        Button {
                            closeSheet()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignColors.text.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Period info display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if !periods.isEmpty {
                                Text("\(periods.count) period\(periods.count == 1 ? "" : "s") saved")
                                    .font(.custom("Raleway-Medium", size: 14))
                                    .foregroundColor(DesignColors.text.opacity(0.7))
                            }

                            if currentDuration > 0 {
                                Text("Current: \(currentDuration) days")
                                    .font(.custom("Raleway-SemiBold", size: 15))
                                    .foregroundColor(DesignColors.accent)
                            } else if periods.isEmpty {
                                Text("No periods selected yet")
                                    .font(.custom("Raleway-Regular", size: 14))
                                    .foregroundColor(DesignColors.text.opacity(0.4))
                            }
                        }

                        Spacer()

                        // Confirm current period button - add to list
                        if tutorialStep == .complete && currentStart != nil && currentEnd != nil {
                            Button {
                                confirmCurrentPeriod()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Add")
                                        .font(.custom("Raleway-SemiBold", size: 14))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(DesignColors.accent)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider()
                }
                .background(Color(UIColor.systemGroupedBackground))

                // Calendar content
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 32) {
                            ForEach(months, id: \.self) { month in
                                MonthView(
                                    month: month,
                                    periodStart: currentStart,
                                    periodEnd: currentEnd,
                                    periodDates: allPeriodDates,
                                    currentSelectionDates: currentSelectionDates,
                                    tutorialStep: tutorialStep,
                                    onDayTap: handleDayTap
                                )
                                .id(month)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .onAppear {
                        // Scroll to current month
                        let currentMonth = calendar.startOfMonth(for: Date())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentMonth, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))

            // Tutorial popup overlay
            if showTutorialPopup && tutorialStep != .complete {
                VStack {
                    Spacer()

                    // Tutorial card
                    VStack(spacing: 12) {
                        // Step indicator - using darker colors for accessibility (WCAG contrast)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    tutorialStep == .selectStart
                                        ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 8, height: 8)

                            Rectangle()
                                .fill(
                                    tutorialStep == .selectEnd ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 20, height: 2)

                            Circle()
                                .fill(
                                    tutorialStep == .selectEnd ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 8, height: 8)
                        }

                        Text(tutorialTitle)
                            .font(.custom("Raleway-Bold", size: 18))
                            .foregroundColor(DesignColors.text)

                        Text(tutorialMessage)
                            .font(.custom("Raleway-Regular", size: 15))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            .multilineTextAlignment(.center)

                        // Animated hand icon
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignColors.accentSecondary)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .opacity(pulseAnimation ? 0.85 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                            .onAppear {
                                pulseAnimation = true
                            }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showTutorialPopup = false
                            }
                        } label: {
                            Text("Got it")
                                .font(.custom("Raleway-SemiBold", size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(DesignColors.accentWarm)
                                )
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // First period complete popup - ask to add more or save
            if showTutorialPopup && tutorialStep == .complete && !hasSaved && periods.isEmpty {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)

                        Text("Period marked!")
                            .font(.custom("Raleway-Bold", size: 20))
                            .foregroundColor(DesignColors.text)

                        Text("\(currentDuration) days selected")
                            .font(.custom("Raleway-Regular", size: 15))
                            .foregroundColor(DesignColors.text.opacity(0.7))

                        Text("Do you remember previous periods?")
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundColor(DesignColors.text.opacity(0.6))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button {
                                // Add current and allow more
                                confirmCurrentPeriod()
                                withAnimation {
                                    showTutorialPopup = false
                                }
                            } label: {
                                Text("Add more")
                                    .font(.custom("Raleway-SemiBold", size: 15))
                                    .foregroundColor(DesignColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .strokeBorder(DesignColors.accent, lineWidth: 1.5)
                                    )
                            }

                            Button {
                                closeSheet()
                            } label: {
                                Text("Done")
                                    .font(.custom("Raleway-SemiBold", size: 15))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(DesignColors.accent)
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Month View

private struct MonthView: View {
    let month: Date
    let periodStart: Date?
    let periodEnd: Date?
    let periodDates: Set<Date>
    let currentSelectionDates: Set<Date>
    let tutorialStep: PeriodCalendarSheet.TutorialStep
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    // Check if any period continues from previous month
    private var periodContinuesFromPrevious: Bool {
        let firstDayOfMonth = calendar.startOfMonth(for: month)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: firstDayOfMonth) else { return false }
        return periodDates.contains(calendar.startOfDay(for: dayBefore)) && periodDates.contains(firstDayOfMonth)
    }

    // Check if any period continues to next month
    private var periodContinuesToNext: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: month)) else {
            return false
        }
        guard let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { return false }
        return periodDates.contains(calendar.startOfDay(for: lastDayOfMonth)) && periodDates.contains(nextMonth)
    }

    // Count period days in this month
    private var periodDaysInMonth: Int {
        let firstDay = calendar.startOfMonth(for: month)
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) else { return 0 }

        return periodDates.filter { date in
            date >= firstDay && date < nextMonth
        }.count
    }

    private var daysInMonth: [Date?] {
        let firstDay = calendar.startOfMonth(for: month)
        var weekday = calendar.component(.weekday, from: firstDay)
        // Convert to Monday = 0 format
        weekday = (weekday + 5) % 7

        var days: [Date?] = []

        // Add empty slots for days before the first day
        for _ in 0..<weekday {
            days.append(nil)
        }

        // Add all days of the month
        let range = calendar.range(of: .day, in: .month, for: month)!
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month header with period indicators
            HStack(spacing: 8) {
                // Arrow from previous month
                if periodContinuesFromPrevious {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                }

                Text(monthName)
                    .font(.custom("Raleway-SemiBold", size: 18))
                    .foregroundColor(DesignColors.text)

                // Period days count badge
                if periodDaysInMonth > 0 {
                    Text("\(periodDaysInMonth)d")
                        .font(.custom("Raleway-Medium", size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignColors.accent)
                        )
                }

                // Arrow to next month
                if periodContinuesToNext {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // Days grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let dayDate = calendar.startOfDay(for: date)
                        let isStart = periodStart.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                        let isEnd = periodEnd.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                        let isCurrentSelection = currentSelectionDates.contains(dayDate)
                        let isSavedPeriod = periodDates.contains(dayDate) && !isCurrentSelection

                        DayCell(
                            date: date,
                            isStartDay: isStart,
                            isEndDay: isEnd,
                            isPeriodDay: periodDates.contains(dayDate),
                            isCurrentSelection: isCurrentSelection,
                            isSavedPeriod: isSavedPeriod,
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
                            tutorialStep: tutorialStep,
                            onTap: {
                                onDayTap(date)
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isStartDay: Bool
    let isEndDay: Bool
    let isPeriodDay: Bool
    let isCurrentSelection: Bool
    let isSavedPeriod: Bool
    let isToday: Bool
    let isFuture: Bool
    let tutorialStep: PeriodCalendarSheet.TutorialStep
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background for period days
                if isPeriodDay {
                    Circle()
                        .fill(isCurrentSelection ? DesignColors.accent : DesignColors.accent.opacity(0.6))
                        .scaleEffect(isStartDay || isEndDay ? 1.0 : 0.85)
                } else if isToday {
                    Circle()
                        .strokeBorder(DesignColors.accent, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }

                // Highlight ring for start/end days of current selection
                if isStartDay || isEndDay {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .scaleEffect(0.9)
                }

                // Checkmark for saved periods
                if isSavedPeriod {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(DesignColors.accent)
                                        .frame(width: 12, height: 12)
                                )
                        }
                    }
                    .frame(width: 44, height: 44)
                    .offset(x: -4, y: -4)
                }

                // Day number
                Text(dayNumber)
                    .font(.custom(isStartDay || isEndDay ? "Raleway-Bold" : "Raleway-Medium", size: 16))
                    .foregroundColor(
                        isFuture
                            ? DesignColors.text.opacity(0.3)
                            : isPeriodDay ? .white : isToday ? DesignColors.accent : DesignColors.text
                    )
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

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

private struct SymptomChip: View {
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

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}

// MARK: - Preview

#Preview("Cycle Data") {
    CycleDataView(
        lastPeriodDate: .constant(Date()),
        cycleDuration: .constant(28),
        periodDuration: .constant(5),
        cycleRegularity: .constant(.regular),
        flowIntensity: .constant(3),
        selectedSymptoms: .constant([.cramping, .headache, .moodSwings]),
        usesContraception: .constant(false),
        contraceptionType: .constant(nil),
        onNext: {},
        onBack: { print("Back tapped") }
    )
}
