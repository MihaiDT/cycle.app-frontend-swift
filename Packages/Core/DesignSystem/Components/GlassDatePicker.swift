import SwiftUI

// MARK: - Glass Date Picker

public struct GlassDatePicker: View {
    @Binding public var selection: Date
    public let label: String
    public let displayedComponents: DatePicker.Components

    public init(
        selection: Binding<Date>,
        label: String,
        displayedComponents: DatePicker.Components = .date
    ) {
        self._selection = selection
        self.label = label
        self.displayedComponents = displayedComponents
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(.custom("Raleway-Medium", size: 16))
                .foregroundColor(DesignColors.text.opacity(0.75))

            Spacer()

            DatePicker(
                "",
                selection: $selection,
                displayedComponents: displayedComponents
            )
            .labelsHidden()
            .tint(DesignColors.link)
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
                            lineWidth: 0.5
                        )
                }
        }
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
    }
}

#Preview("Glass Date Picker") {
    ZStack {
        LinearGradient(
            colors: [.white, Color(red: 0.85, green: 0.75, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 16) {
            GlassDatePicker(
                selection: .constant(Date()),
                label: "Birth date"
            )

            GlassDatePicker(
                selection: .constant(Date()),
                label: "Birth time",
                displayedComponents: .hourAndMinute
            )
        }
        .padding(.horizontal, 32)
    }
}
