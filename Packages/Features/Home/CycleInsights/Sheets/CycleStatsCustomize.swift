import SwiftUI

// MARK: - Cycle Stats Customize
//
// Pushed on top of the Cycle Stats navigation stack. Lets the user
// reorder the visible cards and toggle any card between shown and
// hidden. The screen mutates a `CycleStatsLayout` binding; the
// parent is responsible for persisting the result (debounced in the
// reducer, so dragging doesn't hammer UserDefaults).
//
// Native `List` is used because it gives us free drag-to-reorder
// with haptics, VoiceOver support, and Dynamic Type without any
// re-implementation. The surrounding chrome is styled to match the
// rest of the app — warm journey background, Raleway labels, no
// iOS-default grey grouped header.

struct CycleStatsCustomizeView: View {
    @Binding var layout: CycleStatsLayout
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editMode: EditMode = .active

    var body: some View {
        ZStack {
            JourneyAnimatedBackground(animated: false)
                .ignoresSafeArea()

            list
        }
        .navigationTitle("Customize stats")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
    }

    @ViewBuilder
    private var list: some View {
        List {
            visibleSection
            hiddenSection
            resetSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Sections

    @ViewBuilder
    private var visibleSection: some View {
        Section {
            ForEach(layout.visibleOrder, id: \.self) { card in
                row(for: card, isVisible: true)
            }
            .onMove(perform: move)
        } header: {
            sectionHeader("Cycle stats")
        } footer: {
            Text("Drag to reorder. Tap the circle to hide a card.")
                .font(.raleway("Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.8))
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var hiddenSection: some View {
        let hiddenCards = layout.order.filter { layout.hidden.contains($0) }

        Section {
            if hiddenCards.isEmpty {
                Text("Nothing hidden.")
                    .font(.raleway("Regular", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
            } else {
                ForEach(hiddenCards, id: \.self) { card in
                    row(for: card, isVisible: false)
                }
            }
        } header: {
            sectionHeader("Hidden")
        }
    }

    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button {
                let animation: Animation = reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.25)
                withAnimation(animation) {
                    layout = .default
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Reset to default")
                        .font(.raleway("Medium", size: 14, relativeTo: .callout))
                }
                .foregroundStyle(DesignColors.accentWarmText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(rowBackground)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for card: CycleStatsCard, isVisible: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            toggleButton(for: card, isVisible: isVisible)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.displayName)
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)

                Text(card.blurb)
                    .font(.raleway("Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)
        }
        .padding(.vertical, 6)
        .listRowBackground(rowBackground)
        .listRowSeparator(.hidden)
        // Custom toggle button handles add/remove; suppressing the
        // native delete circle keeps the row visually calm while
        // leaving the trailing drag grip intact in edit mode.
        .deleteDisabled(true)
        .moveDisabled(!isVisible)
    }

    @ViewBuilder
    private func toggleButton(for card: CycleStatsCard, isVisible: Bool) -> some View {
        Button {
            toggle(card)
        } label: {
            Image(systemName: isVisible ? "minus.circle.fill" : "plus.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(isVisible ? DesignColors.accentWarm : DesignColors.statusSuccess)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVisible
            ? "Hide \(card.displayName)"
            : "Show \(card.displayName)")
    }

    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DesignColors.text.opacity(DesignColors.borderOpacitySubtle), lineWidth: 0.6)
            }
            .padding(.vertical, 2)
    }

    // MARK: - Mutations

    /// Rebuilds the canonical `order` array when the user rearranges
    /// the visible subset. Hidden cards keep their prior relative
    /// position at the tail so unhiding one later restores the spot
    /// the user had it in before hiding it.
    private func move(from source: IndexSet, to destination: Int) {
        var visible = layout.visibleOrder
        visible.move(fromOffsets: source, toOffset: destination)
        let hiddenInOrder = layout.order.filter { layout.hidden.contains($0) }
        layout.order = visible + hiddenInOrder
    }

    private func toggle(_ card: CycleStatsCard) {
        let animation: Animation = reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.22)
        withAnimation(animation) {
            if layout.hidden.contains(card) {
                layout.hidden.remove(card)
            } else {
                layout.hidden.insert(card)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
            .tracking(1.2)
            .foregroundStyle(DesignColors.textSecondary.opacity(0.8))
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}
