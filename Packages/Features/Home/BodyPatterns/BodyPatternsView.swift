import ComposableArchitecture
import SwiftUI

// MARK: - Body Patterns View
//
// Root view for the Body Patterns destination screen. Shell mirrors
// the Cycle Stats / Cycle Detail surfaces:
//   - `AppleHealthBackground` extending edge-to-edge.
//   - `NavigationStack` wrapping the scroll content so the native
//     toolbar (back chevron + title + info trailing) reads at iOS-
//     native sizing, identical to every other pushed screen.
//   - 14pt screen gutter (`AppLayout.screenHorizontal`) + 24pt
//     vertical rhythm between cards.
//
// Phase 1: list of mocked active + emerging patterns + footer rows.
// Empty state branch when the feature has no patterns to surface.

public struct BodyPatternsView: View {
    @Bindable var store: StoreOf<BodyPatternsFeature>

    /// Currently focused pattern in the Active carousel. Drives the
    /// custom page-dot indicator so it animates in lock-step with
    /// the swipe gesture instead of a frame behind. Nil until the
    /// first appearance / first scroll settles on a card.
    @State private var activeFocusedID: String?

    /// Same as above for the Emerging carousel. Kept separate so
    /// the two indicators don't share a "focused" state if both
    /// are on screen.
    @State private var emergingFocusedID: String?

    public init(store: StoreOf<BodyPatternsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppleHealthBackground()
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Why-Engine reading — placed at the very
                        // top so the synthesis lands first when
                        // the user opens the screen. Same section
                        // shape as "Your steady rhythms" /
                        // "Just starting to show" below: label +
                        // body card with a 12pt gap. Hidden when
                        // the engine returns nil (empty cycle,
                        // nothing to say) — the screen falls back
                        // to the logging hero as its first card.
                        if let reading = store.overviewReading {
                            VStack(alignment: .leading, spacing: 12) {
                                BodyPatternsSectionLabel(
                                    label: "Reading",
                                    count: 0
                                )
                                BodyPatternsReadingCard(reading: reading)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }

                        // Logging hero — fuses the previous
                        // "How are you feeling?" CTA card and
                        // the bottom "Recently logged" chip
                        // strip into one surface. Header (eyebrow
                        // + title + `+`) is invariant; the body
                        // morphs between the empty-state copy
                        // and the chip strip when `recentLogs`
                        // changes. Hidden symptoms are still the
                        // ones already surfaced as patterns
                        // below — no double-display of "Cramps"
                        // etc.
                        LoggingActionCard(
                            recentLogs: store.recentLogs,
                            hiddenSymptomRaws: hiddenChipSymptoms,
                            onLogTapped: {
                                store.send(.logSymptomsTapped)
                            },
                            onChipTap: { date, symptom in
                                store.send(.recentLogTapped(date, symptomRaw: symptom.rawValue))
                            }
                        )
                        .padding(.top, store.overviewReading == nil ? 8 : 0)
                        .padding(.bottom, 12)

                        if store.isEmpty {
                            BodyPatternsEmptyWidget(
                                onLogSymptomsTapped: {
                                    store.send(.logSymptomsTapped)
                                },
                                logsCount: store.recentLogs.count
                            )
                        } else {
                            patternsList
                        }

                        // Learn more carousel moved to the
                        // About screen (header `i` button) so
                        // the main surface stays focused on
                        // detected patterns + the logging hero.
                    }
                    .padding(.horizontal, AppLayout.screenHorizontal)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Body Patterns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(
                item: Binding(
                    get: { store.presentedDestination },
                    set: { newValue in
                        if newValue == nil {
                            store.send(.destinationDismissed)
                        }
                    }
                )
            ) { destination in
                switch destination {
                case .about:
                    BodyPatternsAboutScreen()
                case .howPatternsWork:
                    HowPatternsWorkScreen()
                case .whenToSeeDoctor:
                    WhenToSeeDoctorScreen()
                case .patternDetail(let pattern):
                    PatternDetailScreen(pattern: pattern)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.dismissTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .principal) {
                    Text("Body Patterns")
                        .font(AppTypography.rowTitleEmphasized)
                        .foregroundStyle(DesignColors.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.infoTapped)
                    } label: {
                        Image(systemName: "info")
                            .foregroundStyle(DesignColors.text)
                    }
                    .glassToolbar()
                    .accessibilityLabel("About Body Patterns")
                }
            }
        }
        .tint(DesignColors.text)
        .task {
            store.send(.onAppear)
        }
    }

    // MARK: - Patterns carousel
    //
    // Active and Emerging each get their own horizontal paged
    // ScrollView with a scroll-driven scale + opacity transition on
    // the off-centre cards — the "Mindfulness" pattern from Apple
    // Health where cards shrink and dim as they leave the focus
    // window. The active card stays at full size; neighbours peek
    // smaller and softer, communicating depth and "more to swipe".
    //
    // Implementation notes:
    //   - `scrollTargetBehavior(.paging)` snaps one card per swipe.
    //   - `scrollTransition(.interactive)` runs every frame of the
    //     gesture, so the scale animates with the finger, not after.
    //   - Custom page dots below — we track the focused pattern via
    //     `scrollPosition(id:)` so the indicator is in lock-step
    //     with the rendered card, not lagging an animation.
    //   - Inner card carries the screen gutter; outer ScrollView
    //     spans edge-to-edge so swipes register at the rails.

    /// Symptom raw values whose display names already surface
    /// as their own pattern card on this screen. Filtered out
    /// of the `LoggingActionCard` chip strip so the user doesn't
    /// see e.g. "Cramps" in both the patterns carousel and the
    /// chip row.
    private var hiddenChipSymptoms: Set<String> {
        Set(
            (store.active + store.emerging)
                .compactMap { pattern -> String? in
                    SymptomType.allCases
                        .first { $0.displayName == pattern.symptomDisplayName }?
                        .rawValue
                }
        )
    }

    @ViewBuilder
    private var patternsList: some View {
        if !store.active.isEmpty {
            sectionHeader(
                label: "Your steady rhythms",
                patterns: store.active,
                focusedID: activeFocusedID
            )
            patternsCarousel(
                patterns: store.active,
                focusedID: stableBinding(for: $activeFocusedID)
            )
            .onAppear {
                if activeFocusedID == nil {
                    activeFocusedID = store.active.first?.id
                }
            }
            // Page dots rendered at the section level (not
            // inside the carousel function) so the cards'
            // own transition animation can't make the dots
            // flicker on swipe — the dots live in their own
            // layout slot, untouched by scroll position
            // changes inside the carousel.
            if store.active.count > 1 {
                AppPageDots(
                    ids: store.active.map(\.id),
                    focusedID: activeFocusedID
                )
            }
        }

        if !store.emerging.isEmpty {
            sectionHeader(
                label: "Just starting to show",
                patterns: store.emerging,
                focusedID: emergingFocusedID
            )
            patternsCarousel(
                patterns: store.emerging,
                focusedID: stableBinding(for: $emergingFocusedID)
            )
            .onAppear {
                if emergingFocusedID == nil {
                    emergingFocusedID = store.emerging.first?.id
                }
            }
            if store.emerging.count > 1 {
                AppPageDots(
                    ids: store.emerging.map(\.id),
                    focusedID: emergingFocusedID
                )
            }
        }
    }

    /// Wraps a `Binding<String?>` so nil writes from
    /// `.scrollPosition(id:)` are ignored. SwiftUI clears the
    /// binding to nil during intermediate swipe positions (no
    /// card centred enough to be the "focused" one), which made
    /// `AppPageDots` collapse to "no active dot" and read as
    /// the navigation disappearing. Keep the last committed ID
    /// until the next non-nil settles in — dots stay solid
    /// across the gesture and only animate the active pill at
    /// the snap.
    private func stableBinding(for source: Binding<String?>) -> Binding<String?> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if let value = newValue {
                    source.wrappedValue = value
                }
            }
        )
    }

    /// Plain section header — same vocabulary as the standalone
    /// `BodyPatternsSectionLabel`. Dots live under the carousel
    /// instead of inline so the row reads cleanly without
    /// dots "decorating" the label.
    @ViewBuilder
    private func sectionHeader(
        label: String,
        patterns: [DetectedPattern],
        focusedID: String?
    ) -> some View {
        BodyPatternsSectionLabel(label: label, count: patterns.count)
    }

    @ViewBuilder
    private func patternsCarousel(
        patterns: [DetectedPattern],
        focusedID: Binding<String?>
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(patterns.enumerated()), id: \.element.id) { index, pattern in
                        PatternWidgetCard(
                            pattern: pattern,
                            onTap: { store.send(.patternTapped(pattern)) }
                        )
                        .padding(.horizontal, AppLayout.screenHorizontal)
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .scaleEffect(
                                    phase.isIdentity ? 1.0 : (1.0 - 0.10 * abs(phase.value))
                                )
                                .opacity(
                                    phase.isIdentity ? 1.0 : (1.0 - 0.40 * abs(phase.value))
                                )
                        }
                        // Cascade entrance dropped — the
                        // implicit `.animation(value: patterns.count)`
                        // was firing on every reflow during a
                        // swipe and made `AppPageDots`
                        // re-evaluate, which read as the
                        // navigation "disappearing" between
                        // cards. Cards now slide in plain
                        // (system carousel feel, like the
                        // Home-screen widget stack the user
                        // referenced).
                        .id(pattern.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: focusedID)
            .scrollIndicators(.hidden)
            // Drop the outer gutter so the ScrollView fills the
            // screen edge-to-edge. Each card re-applies the gutter
            // internally (see `.padding(.horizontal,
            // screenHorizontal)` above) so the editorial column
            // alignment is preserved while the swipe gesture
            // captures the full width.
            .padding(.horizontal, -AppLayout.screenHorizontal)
            // Allow the scaled-down neighbours' shadows to render
            // outside the scroll bounds without a hard clip line.
            .scrollClipDisabled()
            .frame(height: BodyPatternsView.carouselHeight)

            // Page dots rendered at section level — see
            // `patternsList` — so they sit outside this
            // VStack's transition envelope.
        }
    }

    /// Page-indicator dots now provided by the shared
    /// `AppPageDots` component (see callsites in
    /// `patternsList`) — kept consistent with any other
    /// carousel surface in the app.

    /// Height anchor for the carousel ScrollView. Sized to the
    /// tallest card variant (3-line editorial body). Centralised
    /// here so pattern card edits + carousel sizing stay in sync.
    private static let carouselHeight: CGFloat = 250
}
