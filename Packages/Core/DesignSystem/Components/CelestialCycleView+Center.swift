import SwiftUI

// MARK: - Center Content, Gesture, and Context Pills
//
// Extracted from CelestialCycleView.swift to keep file sizes under ~500L.
// Contains: center text composition, drag center, contextual center,
// log period button, gesture overlay + drag handler, context pills, and
// small presentation helpers (pill, phaseGradient, dismiss, haptic, dayForAngle).

extension CelestialCycleView {
    // MARK: - Center Content

    @ViewBuilder
    var centerContentView: some View {
        let collapse = hideProgress
        let counterScale: CGFloat = 1.0 + collapse * 1.2

        VStack(spacing: 2) {
            if isDragging {
                dragCenterView(counterScale: counterScale)
            } else {
                contextualCenterView(collapse: collapse, counterScale: counterScale)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
    }

    func dragCenterView(counterScale: CGFloat) -> some View {
        let dayNum = periodDayFromServer ?? displayDay
        return VStack(spacing: 0) {
            Text("Day")
                .font(.raleway("Medium", size: 14, relativeTo: .callout))
                .foregroundColor(DesignColors.textSecondary)

            Text("\(dayNum)")
                .font(.raleway("Bold", size: 48, relativeTo: .largeTitle))
                .foregroundStyle(phaseGradient(0.85, 0.75))
                .overlay {
                    Text("\(dayNum)")
                        .font(.raleway("Bold", size: 48, relativeTo: .largeTitle))
                        .foregroundStyle(.ultraThinMaterial)
                        .blendMode(.overlay)
                }
                .contentTransition(.numericText(countsDown: dayNum < todayCycleDay))
                .scaleEffect(1.08)

            Text(displayPhase.displayName)
                .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                .foregroundColor(displayPhase.orbitColor.opacity(0.8))
                .contentTransition(.numericText())
        }
        .scaleEffect(counterScale)
    }

    @ViewBuilder
    func contextualCenterView(collapse: Double, counterScale: CGFloat) -> some View {
        // Title
        Text(centerTitle)
            .font(.raleway("Bold", size: 22, relativeTo: .title2))
            .foregroundStyle(phaseGradient(0.9, 0.8))
            .multilineTextAlignment(.center)
            .contentTransition(.numericText())
            .opacity(1 - collapse * 0.5)

        // Subtitle
        Text(centerSubtitle)
            .font(.raleway("Bold", size: 28, relativeTo: .title))
            .foregroundStyle(phaseGradient(0.85, 0.75))
            .overlay {
                Text(centerSubtitle)
                    .font(.raleway("Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(.ultraThinMaterial)
                    .blendMode(.overlay)
            }
            .multilineTextAlignment(.center)
            .contentTransition(.numericText())
            .scaleEffect(counterScale)

        // Day pill (hidden during late/overdue state)
        if !isOverdue {
            let pillDay = periodDayFromServer ?? displayDay
            HStack(spacing: 6) {
                Text("Day \(pillDay)")
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .foregroundColor(displayPhase.orbitColor.opacity(0.8))
                Circle()
                    .fill(displayPhase.orbitColor.opacity(0.4))
                    .frame(width: 3, height: 3)
                    .accessibilityHidden(true)
                Text(displayPhase.displayName)
                    .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                    .foregroundColor(DesignColors.textSecondary.opacity(0.7))
            }
            .opacity(1 - collapse)
            .frame(height: (1 - collapse) * 16, alignment: .center)
            .clipped()
        }
    }

    // MARK: - Log Period Button

    func logPeriodButton(_ action: @escaping (Date?) -> Void) -> some View {
        let isOnPeriod = cycle.isConfirmedPeriod(effectiveDate)
        return Button {
            action(calendarDate)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOnPeriod ? "pencil" : "drop.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
                Text(isOnPeriod ? "Edit Period" : "Log Period")
                    .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
            }
            .foregroundColor(CyclePhase.menstrual.orbitColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule().strokeBorder(
                            CyclePhase.menstrual.orbitColor.opacity(0.3),
                            lineWidth: 0.5
                        )
                    }
            }
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - Gesture Overlay

    var gestureOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20

            Color.clear
                .contentShape(Circle().subtracting(Circle().inset(by: 80)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(value: value, center: center, radius: radius)
                        }
                        .onEnded { _ in
                            lastDragAngle = nil
                            withAnimation(reduceMotion ? nil : .appBalanced) {
                                isDragging = false
                                if exploringDay == todayCycleDay { exploringDay = nil }
                            }
                            haptic(.light)
                        }
                )
        }
        .frame(width: 340, height: 340)
    }

    func handleDrag(value: DragGesture.Value, center: CGPoint, radius: Double) {
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let dist = sqrt(dx * dx + dy * dy)

        guard dist > radius * 0.6 && dist < radius * 1.45 else {
            if isDragging {
                withAnimation(reduceMotion ? nil : .appBalanced) {
                    isDragging = false
                    lastDragAngle = nil
                }
            }
            return
        }

        let angle = atan2(dy, dx)

        if !isDragging {
            isDragging = true
            calendarDate = nil
            lastDragAngle = angle
            let day = dayForAngle(angle)
            exploringDay = day
            lastHapticPhase = cycle.phase(forCycleDay: day)
            haptic(.light)
            return
        }

        guard let prevAngle = lastDragAngle else {
            lastDragAngle = angle
            return
        }

        var delta = angle - prevAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        let dayAngle = (2 * .pi) / Double(max(cycle.effectiveCycleLength, 1))
        let daysMoved = Int((delta / dayAngle).rounded())

        if daysMoved != 0 {
            let step = daysMoved > 0 ? 1 : -1
            let current = exploringDay ?? todayCycleDay
            let newDay = current + step
            guard newDay >= 1, newDay <= cycle.effectiveCycleLength else {
                lastDragAngle = angle
                return
            }
            exploringDay = newDay
            lastDragAngle = prevAngle + Double(step) * dayAngle
            haptic(.light)

            let newPhase = cycle.phase(forCycleDay: newDay)
            if newPhase != lastHapticPhase {
                lastHapticPhase = newPhase
                haptic(.medium)
            }
        }
    }

    // MARK: - Context Pills

    var contextPills: some View {
        HStack(spacing: 10) {
            if isExploring {
                if !isDragging {
                    Button {
                        dismissSelection()
                    } label: {
                        pill(
                            icon: "arrow.uturn.backward",
                            text: "Back to today",
                            color: DesignColors.textSecondary
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                if cycle.isLate {
                    pill(
                        icon: "calendar",
                        text: cycle.daysLate == 1 ? "1 day late" : "\(cycle.daysLate) days late",
                        color: CyclePhase.menstrual.glowColor
                    )
                } else if let n = cycle.nextPeriodIn, n >= 0 {
                    pill(
                        icon: "calendar",
                        text: n == 0 ? "Period today" : "\(n)d until period",
                        color: CyclePhase.menstrual.glowColor
                    )
                }
                if cycle.fertileWindowActive {
                    pill(
                        icon: "sparkles",
                        text: "Fertile window",
                        color: CyclePhase.ovulatory.glowColor
                    )
                }
                if !cycle.fertileWindowActive && cycle.nextPeriodIn == nil {
                    pill(
                        icon: "heart.fill",
                        text: displayPhase.insight,
                        color: displayPhase.glowColor
                    )
                }
            }
        }
        .animation(reduceMotion ? nil : .appBalanced, value: isExploring)
        .animation(reduceMotion ? nil : .appBalanced, value: isDragging)
    }

    // MARK: - Helpers

    func pill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .accessibilityHidden(true)
            }
            Text(text).font(.raleway("Medium", size: 12, relativeTo: .caption)).lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(color.opacity(0.08))
                .overlay { Capsule().strokeBorder(color.opacity(0.15), lineWidth: 0.5) }
        }
    }

    func phaseGradient(_ orbitAlpha: Double, _ glowAlpha: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                displayPhase.orbitColor.opacity(orbitAlpha),
                displayPhase.glowColor.opacity(glowAlpha),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func dismissSelection() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) {
            exploringDay = nil
            calendarDate = nil
            isDragging = false
        }
        haptic(.light)
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func dayForAngle(_ angle: Double) -> Int {
        let normalized = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let positive = normalized < 0 ? normalized + 2 * .pi : normalized
        return max(1, min(cycle.effectiveCycleLength, Int(positive / (2 * .pi) * Double(cycle.effectiveCycleLength)) + 1))
    }
}
