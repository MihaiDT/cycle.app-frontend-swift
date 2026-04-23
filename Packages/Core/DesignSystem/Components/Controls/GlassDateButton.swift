import SwiftUI

// MARK: - Glass Date Button

public struct GlassDateButton: View {
    public let label: String
    public let value: String
    public let action: () -> Void

    public init(
        label: String,
        value: String,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundColor(DesignColors.text.opacity(0.75))

                Spacer()

                Text(value)
                    .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                    .foregroundColor(DesignColors.text)
            }
            .padding(.horizontal, 24)
            .frame(minHeight: 57)
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

// MARK: - Date Picker Sheet

public struct DatePickerSheet: View {
    @Binding public var selection: Date
    @Binding public var isPresented: Bool
    public let title: String
    public let displayedComponents: DatePickerComponents

    public init(
        selection: Binding<Date>,
        isPresented: Binding<Bool>,
        title: String,
        displayedComponents: DatePickerComponents = .date
    ) {
        self._selection = selection
        self._isPresented = isPresented
        self.title = title
        self.displayedComponents = displayedComponents
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $selection,
                    displayedComponents: displayedComponents
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                        .foregroundColor(DesignColors.text)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Done")
                            .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                            .foregroundColor(DesignColors.link)
                    }
                }
            }
        }
        .tint(DesignColors.link)
        .scrollDisabled(true)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnboardingBackground()

        VStack(spacing: 16) {
            GlassDateButton(
                label: "Birth date",
                value: "15 Mar 1995",
                action: {}
            )

            GlassDateButton(
                label: "Birth time",
                value: "14:30",
                action: {}
            )
        }
        .padding(.horizontal, 32)
    }
}
