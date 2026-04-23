import Lottie
import SwiftUI

// MARK: - Birth Data View

public struct BirthDataView: View {
    @Binding public var birthDate: Date
    @Binding public var birthTime: Date
    @Binding public var birthPlace: String
    @Binding public var selectedBirthPlace: PlacesAutocompleteTextField.SelectedPlace?
    public let onNext: () -> Void
    public let onBack: (() -> Void)?
    public let onAgeRestriction: (() -> Void)?
    public let onSearchPlace: (@Sendable (String) async -> [PlacesAutocompleteTextField.PlaceResult])?
    public let onSelectPlace:
        (@Sendable (PlacesAutocompleteTextField.PlaceResult) async -> PlacesAutocompleteTextField.SelectedPlace?)?

    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showAgeRestrictionAlert = false

    private let minimumAge = 13

    private var userAge: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    private var isUnderAge: Bool {
        userAge < minimumAge
    }

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
        selectedBirthPlace: Binding<PlacesAutocompleteTextField.SelectedPlace?>,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        onAgeRestriction: (() -> Void)? = nil,
        onSearchPlace: (@Sendable (String) async -> [PlacesAutocompleteTextField.PlaceResult])? = nil,
        onSelectPlace: (
            @Sendable (PlacesAutocompleteTextField.PlaceResult) async -> PlacesAutocompleteTextField.SelectedPlace?
        )? = nil
    ) {
        self._birthDate = birthDate
        self._birthTime = birthTime
        self._birthPlace = birthPlace
        self._selectedBirthPlace = selectedBirthPlace
        self.onNext = onNext
        self.onBack = onBack
        self.onAgeRestriction = onAgeRestriction
        self.onSearchPlace = onSearchPlace
        self.onSelectPlace = onSelectPlace
    }

    public var body: some View {
        OnboardingLayout(
            currentStep: 4,
            totalSteps: 8,
            onBack: onBack,
            onNext: {
                if isUnderAge {
                    showAgeRestrictionAlert = true
                } else {
                    onNext()
                }
            },
            nextButtonEnabled: selectedBirthPlace != nil
        ) {
            VStack(spacing: 0) {
                // Subtitle
                Text("almost there")
                    .font(.raleway("Regular", size: 13, relativeTo: .caption))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(DesignColors.text.opacity(0.5))

                Spacer().frame(height: 12)

                // Title
                Text("When were you born?")
                    .font(.raleway("Bold", size: 24, relativeTo: .title2))
                    .foregroundColor(DesignColors.text)
                    .accessibilityAddTraits(.isHeader)

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

                    PlacesAutocompleteTextField(
                        text: $birthPlace,
                        selectedPlace: $selectedBirthPlace,
                        placeholder: "Where were you born?",
                        onSearch: onSearchPlace,
                        onSelect: onSelectPlace
                    )
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                // Description
                Text("This helps personalize your cycle predictions.")
                    .font(.raleway("Regular", size: 17, relativeTo: .body))
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
        .overlay {
            if showAgeRestrictionAlert {
                AgeRestrictionAlertView(
                    isPresented: $showAgeRestrictionAlert,
                    onDismiss: onAgeRestriction
                )
            }
        }
    }
}

// MARK: - Age Restriction Alert View

private struct AgeRestrictionAlertView: View {
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissAndNavigate()
                }

            // Alert card
            VStack(spacing: 24) {
                // Lottie Animation
                LottieView(animation: .named("ConsentAnimation", bundle: .main))
                    .playing(loopMode: .loop)
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)

                // Title
                Text("Not 13 yet?")
                    .font(.raleway("Bold", size: 22, relativeTo: .title2))
                    .foregroundColor(DesignColors.text)
                    .accessibilityAddTraits(.isHeader)

                // Message
                VStack(spacing: 12) {
                    Text("You must be at least 13 years old to use this app.")
                        .font(.raleway("Medium", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                        .multilineTextAlignment(.center)

                    Text(
                        "This requirement helps us comply with privacy laws designed to protect children, including COPPA and Apple's App Store Guidelines."
                    )
                    .font(.raleway("Regular", size: 14, relativeTo: .body))
                    .foregroundColor(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                }

                // Dismiss button
                Button(action: {
                    dismissAndNavigate()
                }) {
                    Text("I Understand")
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(DesignColors.accent)
                        )
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(DesignColors.background)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isPresented)
    }

    private func dismissAndNavigate() {
        isPresented = false
        onDismiss?()
    }
}

#Preview("Birth Data") {
    BirthDataView(
        birthDate: .constant(Date()),
        birthTime: .constant(Date()),
        birthPlace: .constant(""),
        selectedBirthPlace: .constant(nil),
        onNext: {},
        onBack: { }
    )
}
