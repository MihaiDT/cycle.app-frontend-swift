import SwiftUI

// MARK: - Glass Text Field

public struct GlassTextField: View {
    @Binding public var text: String
    public let placeholder: String

    public init(text: Binding<String>, placeholder: String = "") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(.custom("Raleway-SemiBold", size: 16))
                .foregroundColor(DesignColors.text.opacity(0.75))
        )
        .font(.custom("Raleway-SemiBold", size: 16))
        .foregroundColor(DesignColors.text)
        .multilineTextAlignment(.center)
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

#Preview("Glass Text Field - Empty") {
    ZStack {
        LinearGradient(
            colors: [.white, Color(red: 0.85, green: 0.75, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassTextField(text: .constant(""), placeholder: "Your name")
                .padding(.horizontal, 32)

            GlassTextField(text: .constant("Sarah"), placeholder: "Your name")
                .padding(.horizontal, 32)
        }
    }
}
