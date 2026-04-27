import SwiftUI

// MARK: - Cycle Stats Customize
//
// Apple Health–style preferences screen pushed on top of the Cycle
// Stats stack. Two sections (Cycle stats / Hidden), each row is an
// icon + label + checkbox + drag handle. Bottom anchor: a primary
// "Done" pill, a quiet "Reset to default" link, and a footer
// paragraph describing the behaviour. Native `List` carries the
// drag-to-reorder + VoiceOver wiring; a `safeAreaInset` houses the
// CTA so the list scrolls under it.

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
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAnchor
        }
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        List {
            visibleSection
            hiddenSection
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

    // MARK: - Row

    @ViewBuilder
    private func row(for card: CycleStatsCard, isVisible: Bool) -> some View {
        HStack(spacing: 14) {
            checkbox(isOn: isVisible) { toggle(card) }

            Image(systemName: card.sfSymbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DesignColors.text.opacity(0.65))
                .frame(width: 22)

            Text(card.displayName)
                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
                .lineLimit(1)

            Spacer(minLength: 6)
        }
        .padding(.vertical, 6)
        .listRowBackground(rowBackground)
        .listRowSeparator(.hidden)
        .deleteDisabled(true)
        .moveDisabled(!isVisible)
    }

    @ViewBuilder
    private func checkbox(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? DesignColors.accentWarm : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isOn ? DesignColors.accentWarm : DesignColors.text.opacity(0.25),
                                lineWidth: isOn ? 0 : 1.4
                            )
                    }
                    .frame(width: 22, height: 22)

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .contentShape(Rectangle())
        }
        // `.borderless` (NOT `.plain`) is required when a Button lives
        // inside a List row that's also draggable in edit mode. With
        // `.plain` the row's drag gesture and the button's tap gesture
        // both claim the touch, and UIKit crashes on the second drag
        // session attempt: "attempted to enter new reordering session
        // whilst an existing session was active". `.borderless` carves
        // out a button-only hit zone so drag stays on the row chrome.
        .buttonStyle(.borderless)
        .accessibilityLabel(isOn ? "Visible" : "Hidden")
    }

    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignColors.text.opacity(DesignColors.borderOpacitySubtle), lineWidth: 0.6)
            }
            .padding(.vertical, 2)
    }

    // MARK: - Bottom anchor (Done + Reset + footer)

    @ViewBuilder
    private var bottomAnchor: some View {
        VStack(spacing: 12) {
            doneButton

            Button(action: reset) {
                Text("Reset to default")
                    .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(DesignColors.accentWarmText)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Restores the default order and shows every card again")

            Text("Hidden cards stay in the layout – bring any back into the stats screen by checking it again here.")
                .font(.raleway("Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            // Soft fade so list content scrolling under the inset
            // doesn't visually crash into the CTA. Matches the warm
            // peach backdrop, not a flat divider.
            LinearGradient(
                colors: [
                    DesignColors.journeyBackground.opacity(0),
                    DesignColors.journeyBackground.opacity(0.92),
                    DesignColors.journeyBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var doneButton: some View {
        Button(action: onDismiss) {
            Text("Done")
                .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .heroGlassCapsule()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Saves changes and closes the customize screen")
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

    private func reset() {
        let animation: Animation = reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.25)
        withAnimation(animation) {
            layout = .default
        }
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
            .tracking(1.4)
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}
