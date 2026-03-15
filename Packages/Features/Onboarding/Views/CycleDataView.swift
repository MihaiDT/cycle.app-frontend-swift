import Inject
import SwiftUI

// MARK: - Cycle Data View

public struct CycleDataView: View {
    @ObserveInjection var inject
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
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Page 0: Calendar
                    InlinePeriodCalendarPage(
                        selectedDate: $lastPeriodDate,
                        periodDuration: $periodDuration
                    )
                    .frame(width: geometry.size.width)

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
                    .frame(width: geometry.size.width)

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
                    .frame(width: geometry.size.width)

                    // Page 3: Flow Intensity
                    CycleDataPage(
                        title: "How would you\ndescribe your flow?",
                        subtitle: "Your typical period intensity"
                    ) {
                        FlowIntensitySelector(intensity: $flowIntensity)
                            .padding(.horizontal, 32)
                    }
                    .frame(width: geometry.size.width)

                    // Page 4: Symptoms
                    CycleDataPage(
                        title: "What symptoms do\nyou typically experience?",
                        subtitle: "Select all that apply"
                    ) {
                        InlineSymptomsSelector(selectedSymptoms: $selectedSymptoms)
                    }
                    .frame(width: geometry.size.width)

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
                    .frame(width: geometry.size.width)
                }
                .offset(x: -CGFloat(currentPage) * geometry.size.width)
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
        .enableInjection()
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
