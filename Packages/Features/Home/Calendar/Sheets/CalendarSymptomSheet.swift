import ComposableArchitecture
import Dependencies
import SwiftUI

/// Bottom sheet that drives daily symptom logging. Built on the
/// shared `AppSheetScreen` layout so it inherits the same
/// background, action chrome, and editorial header as every
/// other sheet in the app.
///
/// Inside the layout's content closure:
///   * `SymptomDaySelector` — day pills
///   * `SymptomCategoryTabBar` — category chooser
///   * `SymptomCategoryPage` — symptom grid (search-filtered)
///
/// Bottom bar (search + settings) is overlayed at the bottom
/// edge so it floats over the grid.
///
/// Save flow lives entirely in the reducer: tapping the trailing
/// `✓` fires `saveSymptomsTapped`, which flips `isSavingSymptoms`,
/// runs the diff against SwiftData, then flips `symptomsSaved`
/// and auto-dismisses ~800ms later via `symptomSheetDismissed`.
struct SymptomLoggingSheet: View {
    @Bindable var store: StoreOf<CalendarFeature>
    @State private var activeCategory: SymptomCategory = .smart
    @State private var isShowingSettings: Bool = false
    /// Drives the severity confirmation dialog. Set on
    /// long-press of a symptom card; cleared when the user
    /// picks a level or dismisses the sheet.
    @State private var severityTarget: SymptomType?
    /// Cached confirmed patterns from `PatternDetector`. The
    /// For-you tab promotes these to the top of its grid so
    /// the user's own recurring symptoms surface first when
    /// she's in the matching phase.
    @State private var confirmedPatterns: [PatternDetector.RawPatternSignal] = []

    @Dependency(\.menstrualLocal) private var menstrualLocal

    /// Mirrors the toggle in `SymptomSettingsView`. When false,
    /// the For-you tab is hidden from the category bar and the
    /// active category falls back to `.physical`.
    @AppStorage(SymptomSettingsKeys.forYouTabEnabled)
    private var forYouTabEnabled: Bool = true

    /// Categories actually rendered in the tab bar, after the
    /// For-you toggle filters out `.smart` when the user has
    /// turned it off.
    private var visibleCategories: [SymptomCategory] {
        forYouTabEnabled
            ? SymptomCategory.allCases
            : SymptomCategory.allCases.filter { $0 != .smart }
    }

    private var selectedSymptoms: Set<String> {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return Set(store.loggedDays[key]?.symptoms ?? [])
    }

    /// Per-symptom severity for the active day. Raw value → 1/3/5.
    /// Populated by the reducer on `.symptomToggled` (default 3)
    /// and `.symptomSeverityChanged` (user-picked).
    private var severities: [String: Int] {
        let key = CalendarFeature.dateKey(store.selectedDate)
        return store.loggedDays[key]?.severities ?? [:]
    }

    /// Selected raw values mapped back to `SymptomType` and
    /// preserving insertion order from the reducer's
    /// `loggedDays[key].symptoms` array — the strip on the
    /// bottom of the sheet renders chips in tap order, not
    /// alphabetical, so newly tapped symptoms land at the end
    /// where the user expects them.
    private var selectedSymptomTypes: [SymptomType] {
        let key = CalendarFeature.dateKey(store.selectedDate)
        let raws = store.loggedDays[key]?.symptoms ?? []
        var seen = Set<String>()
        return raws.compactMap { raw in
            guard seen.insert(raw).inserted else { return nil }
            return SymptomType(rawValue: raw)
        }
    }

    /// Static symptom list for the active category, with the
    /// Smart tab resolving dynamically against the user's
    /// current cycle phase + confirmed patterns.
    private var activeCategorySymptoms: [SymptomType] {
        switch activeCategory {
        case .smart:
            return SmartSymptomProvider(
                phase: currentCyclePhase,
                confirmedPatterns: confirmedPatterns
            ).symptoms
        default:
            return activeCategory.symptoms
        }
    }

    /// Cycle phase for the day the sheet is logging — derived
    /// from the reducer's cycle state via the same helper that
    /// drives the calendar's day badges. Returns `nil` when
    /// the user hasn't seeded any cycle data yet.
    private var currentCyclePhase: CyclePhase? {
        CalendarFeature.phaseInfo(
            for: store.selectedDate,
            cycleStartDate: store.cycleStartDate,
            cycleLength: store.cycleLength,
            bleedingDays: store.bleedingDays
        )?.phase
    }

    /// Active category's symptoms, narrowed by `symptomSearchText`
    /// when the user has typed something.
    private var filteredSymptoms: [SymptomType] {
        let term = store.symptomSearchText
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !term.isEmpty else { return activeCategorySymptoms }
        return activeCategorySymptoms.filter {
            $0.displayName.lowercased().contains(term)
        }
    }

    /// Search-field placeholder. Switches between a generic
    /// "find a symptom" (on the For-you tab, where the catalogue
    /// scope isn't a single category) and a category-scoped
    /// hint ("Find in Mood") on the others. Tells the user
    /// what they're searching *over* without an extra label.
    private var searchPlaceholder: String {
        switch activeCategory {
        case .smart:
            return "Find a symptom"
        default:
            return "Find in \(activeCategory.rawValue)"
        }
    }

    /// Eyebrow caps over the title — names the day the user
    /// is logging for so the sheet has a clear temporal anchor
    /// even before they reach the day picker. "TODAY" /
    /// "YESTERDAY" for the freshest two, the weekday name
    /// otherwise. Stays in caps + warm tracked register so it
    /// reads as register, not body copy.
    private var dayEyebrow: String {
        let day = store.selectedDate
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    private var donePhase: AppDoneButton.Phase {
        if store.symptomsSaved { return .success }
        if store.isSavingSymptoms { return .loading }
        return .idle
    }

    var body: some View {
        AppSheetScreen(
            title: "How are you feeling?",
            eyebrow: dayEyebrow,
            navTitle: "Log symptoms",
            headerLayout: .editorial,
            saveState: donePhase,
            // Save is always available — the reducer's diff
            // handles every transition: adding new selections,
            // removing un-toggled ones, or persisting an "all
            // cleared" state when the user wipes the day. If we
            // gated this on a non-empty selection, the user
            // couldn't commit a deletion of everything they had
            // logged for the day.
            canSave: true,
            onClose: {
                store.send(
                    .symptomSheetDismissed,
                    animation: .spring(response: 0.35, dampingFraction: 0.9)
                )
            },
            onSave: {
                store.send(.saveSymptomsTapped, animation: .easeInOut(duration: 0.3))
            }
        ) {
            VStack(spacing: 0) {
                SymptomDaySelector(
                    selectedDate: store.selectedDate,
                    onSelect: { date in
                        store.send(.daySelected(date))
                    }
                )
                // Day selector spans the sheet edge-to-edge —
                // pills carry their own leading inset so they
                // can scroll past the editorial column and read
                // as bleeding off the row, without overflow
                // painting outside the sheet's frame.
                .padding(.bottom, 8)

                SymptomCategoryTabBar(
                    activeCategory: $activeCategory,
                    categories: visibleCategories
                )

                SymptomCategoryPage(
                    symptoms: filteredSymptoms,
                    // Unified warm tint across every category
                    // — keeps the symptom grid tonally consistent
                    // with the Today pill and the selected
                    // strip below, so the screen reads as one
                    // warm-accent system instead of five.
                    tintColor: DesignColors.accentWarm,
                    severities: severities,
                    onToggle: { symptom in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.send(
                            .symptomToggled(symptom),
                            animation: .spring(response: 0.3, dampingFraction: 0.8)
                        )
                    },
                    onLongPress: { symptom in
                        severityTarget = symptom
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                if !selectedSymptomTypes.isEmpty {
                    // Selected strip runs edge-to-edge so its
                    // pills can scroll past the editorial gutter.
                    // The 24pt inset lives on the inner HStack of
                    // `SymptomSelectedStrip` itself.
                    SymptomSelectedStrip(
                        symptoms: selectedSymptomTypes,
                        onRemove: { symptom in
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            store.send(
                                .symptomToggled(symptom),
                                animation: .spring(response: 0.3, dampingFraction: 0.8)
                            )
                        }
                    )
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
                } else {
                    // Soft hint shown only on the empty state —
                    // tells the user the strip will populate
                    // once they tap a card, so the first
                    // selection doesn't feel like a surprise.
                    SymptomSelectionPlaceholder()
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                SymptomBottomBar(
                    searchText: $store.symptomSearchText,
                    placeholder: searchPlaceholder,
                    onOpenSettings: {
                        isShowingSettings = true
                    }
                )
                .padding(.horizontal, 24)
            }
            .padding(.top, 32)
            .padding(.bottom, 36)
            // Soft fade-to-white backdrop so the chrome doesn't
            // sit transparent over the bottom of the grid —
            // cards used to bleed through the placeholder
            // copy. Audit pass 2 made the fade more
            // aggressive (longer 0→0.95 ramp) so the last
            // grid row no longer reads through as half-
            // ghosted icons.
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.0), location: 0.0),
                        .init(color: Color.white.opacity(0.95), location: 0.55),
                        .init(color: Color.white, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)
            )
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8),
                value: selectedSymptomTypes.isEmpty
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            SymptomSettingsView(onClose: { isShowingSettings = false })
        }
        .task {
            // If the sheet was opened from a recent-logs chip on
            // Body Patterns, switch the active tab to the
            // category that owns that symptom — otherwise the
            // user lands on "For you" and can't see the symptom
            // they came from. The reducer clears the pending
            // value once we've consumed it.
            if let raw = store.pendingFocusedSymptomRaw,
               let symptom = SymptomType(rawValue: raw),
               let category = SymptomCategory.allCases.first(where: {
                   $0 != .smart && $0.symptoms.contains(symptom)
               }) {
                activeCategory = category
            }
            if store.pendingFocusedSymptomRaw != nil {
                store.send(.pendingFocusedSymptomCleared)
            }

            // Load confirmed patterns once per sheet open. The
            // local client returns within ~50ms; failure is
            // silent — falls back to phase defaults only.
            do {
                confirmedPatterns = try await menstrualLocal.detectPatterns()
            } catch {
                confirmedPatterns = []
            }
        }
        .onChange(of: forYouTabEnabled) { _, isEnabled in
            // If the user disables For-you while it's the
            // active tab, slide them to Physical so the screen
            // doesn't render a tab that no longer exists.
            if !isEnabled, activeCategory == .smart {
                activeCategory = .physical
            }
        }
        .confirmationDialog(
            "Intensity",
            isPresented: Binding(
                get: { severityTarget != nil },
                set: { if !$0 { severityTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: severityTarget
        ) { symptom in
            Button("Mild") {
                store.send(.symptomSeverityChanged(symptom, 1))
                severityTarget = nil
            }
            Button("Moderate") {
                store.send(.symptomSeverityChanged(symptom, 3))
                severityTarget = nil
            }
            Button("Severe") {
                store.send(.symptomSeverityChanged(symptom, 5))
                severityTarget = nil
            }
            Button("Cancel", role: .cancel) {
                severityTarget = nil
            }
        } message: { symptom in
            Text(symptom.displayName)
        }
    }
}
