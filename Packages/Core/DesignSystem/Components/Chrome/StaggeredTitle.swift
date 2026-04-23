import SwiftUI

// MARK: - Staggered Title
//
// Renders a string as individual glyphs, each rising from below and fading
// in with a staggered spring. Swapping the `text` value re-triggers the
// entrance so the title re-animates when the user pages a carousel. The
// typography matches the `SectionHeader` hero so this drops in as a
// direct replacement wherever a section header needs to react to state.

public struct StaggeredTitle: View {
    public let text: String
    public let fontName: String
    public let fontSize: CGFloat
    public let tracking: CGFloat
    public let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIn: Bool = false

    public init(
        text: String,
        fontName: String = "Bold",
        fontSize: CGFloat = 22,
        tracking: CGFloat = -0.3,
        color: Color = DesignColors.text
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.tracking = tracking
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.raleway(fontName, size: fontSize, relativeTo: .title2))
                    .tracking(tracking)
                    .foregroundStyle(color)
                    .offset(y: animateIn ? 0 : 16)
                    .opacity(animateIn ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.55, dampingFraction: 0.78)
                                .delay(Double(index) * 0.04),
                        value: animateIn
                    )
            }
        }
        .onAppear {
            if reduceMotion {
                animateIn = true
                return
            }
            triggerAnimation()
        }
        .onChange(of: text) { _, _ in
            guard !reduceMotion else {
                animateIn = true
                return
            }
            triggerAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }

    /// Snap the letters to their hidden state without animating the snap,
    /// then flip to `true` a frame later so SwiftUI sees a proper value
    /// change and runs the staggered spring per letter. Doing this via
    /// `withTransaction(animation: nil)` avoids the visible "fall back
    /// down" artefact that a plain `animateIn = false` would cause.
    private func triggerAnimation() {
        var noAnim = Transaction(animation: nil)
        noAnim.disablesAnimations = true
        withTransaction(noAnim) {
            animateIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            animateIn = true
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewHost: View {
        @State private var current: String = "Rhythm"
        var body: some View {
            VStack(spacing: 40) {
                StaggeredTitle(text: current)

                Button("Swap") {
                    current = current == "Rhythm" ? "Journey" : "Rhythm"
                }
            }
            .padding()
        }
    }
    return PreviewHost()
}
