import ComposableArchitecture
import SwiftUI

// MARK: - Pattern Detail Screen
//
// Push destination from `PatternWidgetCard` tap. Apple Health metric-
// detail idiom translated into cycle.app's warm palette:
//
//   ┌─ AppScreenHeader ──────────────────────────────┐
//   │ MENSTRUAL PHASE                                │
//   │ Bloating                                       │
//   └────────────────────────────────────────────────┘
//   ┌─ PatternDayHeatmap (horizontal scroll) ────────┐
//   │ Cycle day  | Mar  Feb  Jan  Dec  →             │
//   │ Day 1      | ●    ●    ●    ●                  │
//   │ Day 3      | ●    ○    ○    ●                  │
//   │            | ⌄  ← chevron toggle               │
//   └────────────────────────────────────────────────┘
//   ┌─ Editorial lede (pattern.editorial body) ──────┐
//   ┌─ PatternDayHeatmap (horizontal scroll) ────────┐
//   ┌─ "Highlights" section label ───────────────────┐
//   ┌─ PatternHighlightsCard (2×2 stat tile grid) ───┐
//   └─ MedicalDeviceDisclaimer ──────────────────────┘
//
// Real data: severity / peak / cycles / trend come from
// `MenstrualLocalClient.patternMetrics` over a 12-month lookback
// against the user's `SymptomRecord` history. Loading state shows
// skeleton-ish empty values until the query resolves; Highlights /
// chart fall back to "—" + empty-state copy when the pattern has no
// logs in the window.
//
// Heatmap: cycles flow rightward as columns; a horizontal `ScrollView`
// handles overflow when the user has more cycles than fit on screen.
// All cycles in the 12-month lookback are shown at once — the
// previous picker chip ("Last 3 / 6 / 12 cycles") was dropped because
// the scroll already handles scope, and a fixed 3-cycle minimum keeps
// the chart's footprint stable for short histories.
//
// Animation contract: cards stagger-fade in on appear. Per the
// DesignSystem rule, the host (this screen) owns the animation; the
// shared visualization components stay static.

struct PatternDetailScreen: View {
    let pattern: DetectedPattern

    @Dependency(\.menstrualLocal) private var menstrualLocal

    @State private var metrics: PatternMetrics?
    @State private var reading: PatternReading?
    @State private var didAppear = false
    @State private var isHeatmapExpanded = false
    @State private var visibleColumnCount: Int = 3
    @State private var visibleDayCount: Int = 2
    @State private var isDisclaimerExpanded = false

    private var resolvedMetrics: PatternMetrics {
        metrics ?? .empty(window: defaultWindow)
    }

    private var defaultWindow: ClosedRange<Date> {
        let now = Date()
        let start = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        return start...now
    }

    /// Top of the screen: title + phase subtitle on the leading
    /// edge, the heatmap on the trailing edge. With 3 cycles the
    /// heatmap is ~220pt wide; title takes the remaining ~130pt.
    /// Heatmap dominates the right side and extends below the title
    /// block — same `top` alignment so they share a single baseline.
    /// Vertical hero: title at full width above, heatmap below.
    /// Heatmap renders a 2-day × 3-cycle preview by default; a
    /// "View more" toggle reveals the full grid when the pattern
    /// has more data than fits in the preview window.
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Canonical screen header — same component used by
            // How Patterns Work, When To See A Doctor, About,
            // and Cycle Stats. Eyebrow names the phase context;
            // title names the pattern. Drops the previous custom
            // 28pt/sentence-subtitle pairing for the app-wide
            // 32pt gradient title + uppercase tracked eyebrow.
            AppScreenHeader(
                eyebrow: "\(pattern.phaseDisplayName) phase",
                title: pattern.symptomDisplayName
            )

            // Editorial lede — short descriptive paragraph that
            // context-sets the pattern before the visualisation.
            // Negative top padding compresses against the header's
            // internal 18pt bottom + the VStack's 12pt spacing so
            // the lede reads as a continuation of the title rather
            // than a detached paragraph 30pt below it.
            Text(pattern.editorial)
                .font(.raleway("Medium", size: 16, relativeTo: .body))
                .tracking(-0.1)
                .foregroundStyle(DesignColors.textPrincipal)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, -22)
                .padding(.bottom, 2)

            PatternDayHeatmap(
                dayLogs: resolvedMetrics.dayLogs,
                phase: pattern.phase,
                highlightedCycleStart: resolvedMetrics.cycles.last?.cycleStartDate,
                targetColumnCount: 3,
                visibleColumnCount: visibleColumnCount,
                visibleDayCount: visibleDayCount,
                showsWatermark: !isHeatmapExpanded,
                symptomTypeRaw: pattern.symptomTypeRaw,
                priorityDay: resolvedMetrics.mostActiveDay
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if heatmapHasOverflow {
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: chevronLeadingInset)
                    viewMoreButton
                    Spacer(minLength: 0)
                }
                // VStack spacing is 12; offset by -2 so the gap to
                // the last cell row matches `cellSpacing` (10pt).
                // Same vertical rhythm as Day 1 → Day 3 inside the
                // column — chevron reads as the next row, not a
                // detached control.
                .padding(.top, -2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Leading inset that lands the chevron button on the same x as
    /// the first cycle column. The button is `cellSize` like every
    /// dot, so sharing the column's leading edge puts it directly
    /// under the column — reads as the next row, not a control in
    /// the gutter.
    ///   inset = dayLabelWidth + gutterToColumnsSpacing
    private var chevronLeadingInset: CGFloat {
        PatternDayHeatmap.dayLabelWidth + PatternDayHeatmap.gutterToColumnsSpacing
    }

    /// True when the pattern has more cycles or more days than the
    /// 3 × 2 preview window can show. Drives the "View more" toggle
    /// — if the preview fits the data, no button is needed.
    private var heatmapHasOverflow: Bool {
        let cycleCount = Set(resolvedMetrics.dayLogs.map(\.cycleStartDate)).count
        let dayCount = Set(resolvedMetrics.dayLogs.map(\.cycleDay)).count
        return cycleCount > 3 || dayCount > 2
    }

    /// Circular chevron toggle — sized smaller than a heatmap cell
    /// (32pt vs 38pt) and rendered on glass with a phase-ink stroke
    /// so it reads as a control echoing the heatmap dots' design
    /// vocabulary, not as another data cell. Chevron rotates 180°
    /// between collapsed (down) and expanded (up). Tapping flips
    /// `isHeatmapExpanded` so the heatmap re-renders without caps.
    /// Wraps the change in `withAnimation` so the column-level
    /// `.transition(...)` cascade fires; the per-column haptic
    /// pulses are scheduled by `triggerCascadeHaptics` to match the
    /// stagger so the user *feels* each column land instead of one
    /// generic tap on tap.
    private var viewMoreButton: some View {
        let palette = BodyPatternsPalette.forPhase(pattern.phase)
        return Button {
            let nextValue = !isHeatmapExpanded
            withAnimation(.easeInOut(duration: 0.28)) {
                isHeatmapExpanded = nextValue
            }
            scheduleCascade(expanding: nextValue)
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .strokeBorder(palette.accent.opacity(0.45), lineWidth: 0.8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .rotationEffect(.degrees(isHeatmapExpanded ? 180 : 0))
                    .animation(
                        .timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.34),
                        value: isHeatmapExpanded
                    )
            }
            .frame(width: PatternDayHeatmap.cellSize, height: PatternDayHeatmap.cellSize)
            .shadow(color: palette.accent.opacity(0.12), radius: 6, x: 0, y: 2)
            .contentShape(Circle())
        }
        .buttonStyle(ChevronCirclePressStyle())
        .accessibilityLabel(isHeatmapExpanded ? "Show less" : "Show more")
    }

    /// Drives the column / day reveal (or hide) cascade. Each step
    /// is its own `DispatchQueue.main.asyncAfter` + `withAnimation`
    /// pair so SwiftUI gets one fresh animation transaction per
    /// column transition — that's what fixes the "after 2 toggles
    /// the order goes random" bug from the previous transition-with-
    /// delay approach. A `light` haptic punctuates each step so the
    /// finger feels every column land.
    private func scheduleCascade(expanding: Bool) {
        let totalCycles = Set(resolvedMetrics.dayLogs.map(\.cycleStartDate)).count
        // Only count cycle days that actually have logs. The
        // heatmap skips empty rows entirely, so the cascade target
        // is the number of distinct logged days (clamped to ≥2 for
        // breathing room on single-day patterns).
        let loggedDays = Set(resolvedMetrics.dayLogs.map(\.cycleDay)).count
        let totalDays = max(2, loggedDays)

        // First haptic fires immediately — feels like the tap was
        // accepted.
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)

        if expanding {
            scheduleStep(
                from: visibleColumnCount,
                to: max(visibleColumnCount, totalCycles),
                stepDelay: 0.08,
                response: 0.46,
                damping: 0.92
            ) { newValue in
                visibleColumnCount = newValue
            }
            scheduleStep(
                from: visibleDayCount,
                to: max(visibleDayCount, totalDays),
                stepDelay: 0.05,
                response: 0.4,
                damping: 0.92,
                hapticIntensity: 0   // skip haptic on day cascade so it doesn't double up with column haptic
            ) { newValue in
                visibleDayCount = newValue
            }
        } else {
            scheduleStep(
                from: visibleColumnCount,
                to: 3,
                stepDelay: 0.06,
                response: 0.4,
                damping: 0.92
            ) { newValue in
                visibleColumnCount = newValue
            }
            scheduleStep(
                from: visibleDayCount,
                to: 2,
                stepDelay: 0.04,
                response: 0.36,
                damping: 0.92,
                hapticIntensity: 0
            ) { newValue in
                visibleDayCount = newValue
            }
        }
    }

    /// Walks `from` → `to` one unit at a time, scheduling a fresh
    /// `withAnimation` block per step. Generic over the property
    /// being animated so column count and day count share the same
    /// scheduler.
    private func scheduleStep(
        from start: Int,
        to end: Int,
        stepDelay: TimeInterval,
        response: Double,
        damping: Double,
        hapticIntensity: CGFloat = 0.45,
        apply: @escaping (Int) -> Void
    ) {
        guard start != end else { return }
        let step = (end > start) ? 1 : -1
        var index = 0
        var current = start
        while current != end {
            current += step
            let next = current
            let delay = TimeInterval(index) * stepDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: response, dampingFraction: damping)) {
                    apply(next)
                }
                if hapticIntensity > 0 {
                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred(intensity: hapticIntensity)
                }
            }
            index += 1
        }
    }

    var body: some View {
        ZStack {
            AppleHealthBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    heroSection
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 8)

                    BodyPatternsSectionLabel(label: "Highlights", count: 0)
                        .padding(.horizontal, 0)

                    PatternHighlightsCard(
                        pattern: pattern,
                        metrics: resolvedMetrics
                    )
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 12)
                    .animation(.easeOut(duration: 0.36).delay(0.16), value: didAppear)

                    // Why-Engine reading — reads the Highlights
                    // tiles aloud as a sentence sequence. Hidden
                    // until metrics resolve so the section doesn't
                    // appear with nothing in it; the engine pulls
                    // mostActiveDay / coOccurringSymptom / trend
                    // from the same metrics the tiles consume.
                    if let reading = reading {
                        BodyPatternsSectionLabel(label: "Reading", count: 0)
                            .padding(.horizontal, 0)
                            .padding(.top, 4)

                        PatternReadingSection(reading: reading)
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 12)
                            .animation(.easeOut(duration: 0.36).delay(0.22), value: didAppear)
                    }

                    CollapsibleMedicalDisclaimer(isExpanded: $isDisclaimerExpanded)
                        .padding(.top, 8)
                        .opacity(didAppear ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.30), value: didAppear)
                }
                .padding(.horizontal, AppLayout.screenHorizontal)
                .padding(.top, 0)
                // Bottom dead space adapts to disclaimer state —
                // tight when collapsed (eyebrow only takes ~50pt),
                // generous when the body is open so the legal copy
                // doesn't sit flush against the home indicator.
                .padding(.bottom, isDisclaimerExpanded ? 40 : 12)
                .animation(.easeOut(duration: 0.32), value: didAppear)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Same toolbar contract as `BodyPatternsView` and the
            // educational explainers — Raleway SemiBold 17pt
            // principal title in cocoa, hairline native back
            // chevron tinted to match. The previous
            // `.navigationTitle("Pattern")` call used the system
            // SF font, which read as foreign next to the parent
            // surface's Raleway title.
            ToolbarItem(placement: .principal) {
                Text("Pattern")
                    .font(.raleway("SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)
            }
        }
        .tint(DesignColors.text)
        .task {
            try? await Task.sleep(nanoseconds: 40_000_000)
            withAnimation { didAppear = true }

            // Initial data load — wrap in a `disablesAnimations`
            // transaction so the heatmap's per-cell / per-column
            // `.transition(...)` cascades don't fire when the
            // metrics first land. Otherwise the cells appear to
            // dip below the bottom edge and reappear on screen
            // entry, because the `withAnimation` context propagates
            // into nested transition modifiers.
            do {
                let result = try await menstrualLocal.patternMetrics(
                    pattern.symptomTypeRaw,
                    pattern.phase
                )
                let computedReading = BodyPatternsReadingEngine.patternReading(
                    pattern: pattern,
                    metrics: result
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    metrics = result
                    reading = computedReading
                }
            } catch {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    metrics = .empty(window: defaultWindow)
                }
            }
        }
    }
}

// MARK: - Press style
//
// Tiny scale + opacity bounce for the chevron toggle. iOS 26's
// glass shader doesn't reach this button (it's not on a card
// surface), so the tactile feedback comes from the ButtonStyle
// alone — scale 0.9 on press, spring back on release.

private struct ChevronCirclePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}
