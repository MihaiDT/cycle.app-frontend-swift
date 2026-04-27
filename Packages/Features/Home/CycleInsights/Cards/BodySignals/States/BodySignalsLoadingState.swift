import SwiftUI

// MARK: - Loading State
//
// Skeleton mirroring the data layout — small icon + caps eyebrow on
// the left, three mini metric tiles below. A subtle pulse animation
// signals "loading" rather than "broken", and the layout matches the
// loaded card exactly so the transition to real data is a calm
// in-place fade with no layout jump.

struct BodySignalsLoadingState: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fill: Color { DesignColors.text.opacity(0.08) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            tileRow
        }
        .opacity(reduceMotion ? 1 : (pulse ? 0.6 : 1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading body signals")
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill)
                    .frame(width: 14, height: 14)
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill)
                    .frame(width: 92, height: 11)
            }
            Spacer(minLength: 4)
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(width: 80, height: 11)
        }
    }

    private var tileRow: some View {
        HStack(spacing: 10) {
            tile
            tile
            tile
        }
    }

    private var tile: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(fill)
                .frame(width: 22, height: 22)
            RoundedRectangle(cornerRadius: 4)
                .fill(fill)
                .frame(width: 38, height: 22)
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(width: 24, height: 9)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 96)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignColors.text.opacity(0.025))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DesignColors.text.opacity(DesignColors.borderOpacitySubtle), lineWidth: 0.6)
                }
        }
    }
}
