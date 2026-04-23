import SwiftUI

// surface reads "the interface heard me" without delaying the
// action itself.

struct CycleHistoryPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.55 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Hide Cycle Dialog
//
// Explains what hiding does before it happens. Hiding is a
// recalibration — sometimes a cycle carries noise (a missed log,
// medication, an event that shifted it) and pulling it out of the
// rolling averages gives the prediction engine cleaner signal.
// Nothing is deleted. The dialog exists so the user picks up that
// nuance without having to discover it later.

struct HideCycleDialog: View {
    let cycleLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var isHidden: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                explanation
                considerSection
                Spacer(minLength: 8)
                toggleRow
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hide cycle")
                .font(.raleway("Bold", size: 24, relativeTo: .title2))
                .tracking(-0.4)
                .foregroundStyle(DesignColors.text)

            Text(cycleLabel)
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .tracking(0.1)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var explanation: some View {
        Text("If a cycle got thrown off by something out of the ordinary, hide it so your averages and predictions stay accurate. The cycle stays in your history, and you can bring it back whenever you want.")
            .font(.raleway("Regular", size: 14, relativeTo: .callout))
            .foregroundStyle(DesignColors.text.opacity(0.82))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var considerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You might want to hide this cycle if:")
                .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
                .foregroundStyle(DesignColors.text)

            VStack(alignment: .leading, spacing: 8) {
                bullet("You forgot to log a period and the gap stretched the count")
                bullet("You were pregnant or had a miscarriage")
                bullet("Birth control made you skip a period on purpose")
                bullet("You took the morning-after pill")
                bullet("Illness, new medication, or major stress threw things off")
            }
        }
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(DesignColors.accentWarm.opacity(0.7))
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
                .font(.raleway("Regular", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.text.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var toggleRow: some View {
        HStack(spacing: 12) {
            Text("Hide this cycle")
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)

            Spacer(minLength: 8)

            Toggle("", isOn: $isHidden)
                .labelsHidden()
                .tint(DesignColors.accentWarmText)
                .onChange(of: isHidden) { _, newValue in
                    if newValue {
                        // Brief pause lets the toggle animation finish
                        // before the sheet slides away — feels less
                        // abrupt than yanking the sheet mid-flip.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            onConfirm()
                        }
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.text.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DesignColors.text.opacity(0.06), lineWidth: 0.6)
                }
        }
    }
}
