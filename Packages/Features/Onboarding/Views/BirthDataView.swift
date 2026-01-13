import SwiftUI

// MARK: - Birth Data View

public struct BirthDataView: View {
    @Binding public var birthDate: Date
    @Binding public var birthTime: Date
    @Binding public var birthPlace: String
    public let onNext: () -> Void
    public let onBack: (() -> Void)?

    @State private var showDatePicker = false
    @State private var showTimePicker = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    public init(
        birthDate: Binding<Date>,
        birthTime: Binding<Date>,
        birthPlace: Binding<String>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self._birthDate = birthDate
        self._birthTime = birthTime
        self._birthPlace = birthPlace
        self.onNext = onNext
        self.onBack = onBack
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 4,
            totalSteps: 8,
            onBack: onBack,
            onNext: onNext,
            nextButtonEnabled: true
        ) {
            VStack(spacing: 0) {
                // Subtitle
                Text("almost there")
                    .font(.custom("Raleway-Regular", size: 13))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(DesignColors.text.opacity(0.5))

                Spacer().frame(height: 12)

                // Title
                Text("When were you born?")
                    .font(.custom("Raleway-Bold", size: 24))
                    .foregroundColor(DesignColors.text)

                Spacer().frame(height: 32)

                // Birth inputs
                VStack(spacing: 16) {
                    GlassDateButton(
                        label: "Birth date",
                        value: dateFormatter.string(from: birthDate),
                        action: { showDatePicker = true }
                    )

                    GlassDateButton(
                        label: "Birth time",
                        value: timeFormatter.string(from: birthTime),
                        action: { showTimePicker = true }
                    )

                    GlassTextField(
                        text: $birthPlace,
                        placeholder: "Birth place (optional)"
                    )
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                // Description
                Text("This helps personalize your cycle predictions.")
                    .font(.custom("Raleway-Regular", size: 17))
                    .foregroundColor(DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selection: $birthDate,
                isPresented: $showDatePicker,
                title: "Select your birth date",
                displayedComponents: .date
            )
        }
        .sheet(isPresented: $showTimePicker) {
            DatePickerSheet(
                selection: $birthTime,
                isPresented: $showTimePicker,
                title: "Select your birth time",
                displayedComponents: .hourAndMinute
            )
        }
    }
}

#Preview("Birth Data") {
    BirthDataView(
        birthDate: .constant(Date()),
        birthTime: .constant(Date()),
        birthPlace: .constant(""),
        onNext: {},
        onBack: { print("Back tapped") }
    )
}
