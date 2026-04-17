import SwiftUI

// MARK: - Inline Period Calendar Page

struct InlinePeriodCalendarPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedDate: Date
    @Binding var periodDuration: Int

    private let calendar = Calendar.current

    // Multiple periods support
    struct Period: Identifiable, Equatable {
        let id = UUID()
        var start: Date
        var end: Date

        var duration: Int {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return days + 1
        }
    }

    @State private var periods: [Period] = []
    @State private var currentStart: Date? = nil
    @State private var currentEnd: Date? = nil

    enum TutorialStep {
        case selectStart
        case selectEnd
        case complete
    }
    @State private var tutorialStep: TutorialStep = .selectStart
    @State private var showTutorialPopup: Bool = true
    @State private var hasSeenTutorial: Bool = false
    @State private var pulseAnimation: Bool = false
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())

    // Generate 6 months back + current month
    private var months: [Date] {
        var dates: [Date] = []
        let today = Date()
        for i in stride(from: -6, through: 0, by: 1) {
            if let date = calendar.date(byAdding: .month, value: i, to: today) {
                dates.append(calendar.startOfMonth(for: date))
            }
        }
        return dates
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var allPeriodDates: Set<Date> {
        var dates: Set<Date> = []
        for period in periods {
            var current = period.start
            while current <= period.end {
                dates.insert(calendar.startOfDay(for: current))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        if let start = currentStart {
            if let end = currentEnd {
                var current = start
                while current <= end {
                    dates.insert(calendar.startOfDay(for: current))
                    guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                    current = next
                }
            } else {
                dates.insert(calendar.startOfDay(for: start))
            }
        }
        return dates
    }

    private var currentSelectionDates: Set<Date> {
        var dates: Set<Date> = []
        guard let start = currentStart else { return dates }
        guard let end = currentEnd else {
            dates.insert(calendar.startOfDay(for: start))
            return dates
        }
        var current = start
        while current <= end {
            dates.insert(calendar.startOfDay(for: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private var currentDuration: Int {
        guard let start = currentStart, let end = currentEnd else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }

    private var averagePeriodDuration: Int {
        var allDurations: [Int] = periods.map { $0.duration }
        if currentDuration > 0 {
            allDurations.append(currentDuration)
        }
        guard !allDurations.isEmpty else { return 5 }
        let avg = allDurations.reduce(0, +) / allDurations.count
        return min(max(avg, 2), 10)
    }

    private func confirmCurrentPeriod() {
        guard let start = currentStart, let end = currentEnd else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            periods.append(Period(start: start, end: end))
            currentStart = nil
            currentEnd = nil
            tutorialStep = .selectStart
            showTutorialPopup = false  // Don't show tutorial again
        }

        // Update period duration with average of all periods
        periodDuration = averagePeriodDuration

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func handleDayTap(_ date: Date) {
        let tappedDate = calendar.startOfDay(for: date)

        // Check if tapping on an existing period to delete it
        if let periodIndex = periods.firstIndex(where: { period in
            var current = period.start
            while current <= period.end {
                if calendar.isDate(current, inSameDayAs: tappedDate) {
                    return true
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return false
        }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                periods.remove(at: periodIndex)
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            switch tutorialStep {
            case .selectStart:
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
                if !hasSeenTutorial {
                    showTutorialPopup = true
                }

            case .selectEnd:
                if let start = currentStart {
                    if tappedDate < start {
                        currentEnd = start
                        currentStart = tappedDate
                    } else {
                        currentEnd = tappedDate
                    }
                    tutorialStep = .complete
                    if !hasSeenTutorial {
                        showTutorialPopup = true
                        hasSeenTutorial = true
                    }
                    // Auto-save to bindings
                    selectedDate = currentStart ?? tappedDate
                    periodDuration = averagePeriodDuration
                }

            case .complete:
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
                showTutorialPopup = false  // Don't show tutorial again
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func getSubtitleText() -> String {
        switch tutorialStep {
        case .selectStart:
            if periods.isEmpty {
                return "Tap the first day of your period"
            } else {
                return "\(periods.count) period\(periods.count == 1 ? "" : "s") added • Add more?"
            }
        case .selectEnd:
            return "Now tap the last day"
        case .complete:
            return "\(currentDuration) days selected"
        }
    }

    private var tutorialTitle: String {
        switch tutorialStep {
        case .selectStart: return "Step 1"
        case .selectEnd: return "Step 2"
        case .complete: return "Perfect!"
        }
    }

    private var tutorialMessage: String {
        switch tutorialStep {
        case .selectStart: return "Tap the first day of your last period"
        case .selectEnd: return "Now tap the last day of your period"
        case .complete: return "Your period is \(currentDuration) days. You can add more periods or continue."
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                Text("When did your\nlast period start?")
                    .font(.raleway("Bold", size: 26, relativeTo: .title2))
                    .foregroundColor(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Spacer().frame(height: 8)

                Text(getSubtitleText())
                    .font(.raleway("Regular", size: 15, relativeTo: .body))
                    .foregroundColor(tutorialStep == .complete ? DesignColors.accent : DesignColors.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: tutorialStep)

                // Period info and Add button
                HStack {
                    Spacer()

                    Button {
                        confirmCurrentPeriod()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .accessibilityHidden(true)
                            Text("Add & mark another")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(DesignColors.accent)
                        )
                    }
                    .accessibilityLabel("Add and mark another period")

                    Spacer()
                }
                .padding(.top, 12)
                .opacity(tutorialStep == .complete && currentStart != nil && currentEnd != nil ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: tutorialStep)

                // Saved periods count
                Text("\(periods.count) period\(periods.count == 1 ? "" : "s") saved")
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
                    .foregroundColor(DesignColors.text.opacity(0.6))
                    .padding(.top, 8)
                    .opacity(periods.isEmpty ? 0 : 1)

                Spacer().frame(height: 16)

                // Swipeable calendar (left/right)
                VStack(spacing: 0) {
                    // Month navigation header
                    HStack {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                displayedMonth =
                                    calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DesignColors.accentWarm)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Previous month")

                        Spacer()

                        Text(monthFormatter.string(from: displayedMonth))
                            .font(.raleway("SemiBold", size: 18, relativeTo: .headline))
                            .foregroundColor(DesignColors.text)
                            .accessibilityAddTraits(.isHeader)

                        Spacer()

                        Button {
                            let nextMonth =
                                calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                            if nextMonth <= calendar.startOfMonth(for: Date()) {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                    displayedMonth = nextMonth
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(
                                    displayedMonth >= calendar.startOfMonth(for: Date())
                                        ? DesignColors.text.opacity(0.2)
                                        : DesignColors.accentWarm
                                )
                                .frame(width: 44, height: 44)
                        }
                        .disabled(displayedMonth >= calendar.startOfMonth(for: Date()))
                        .accessibilityLabel("Next month")
                    }
                    .padding(.horizontal, 24)

                    // Swipeable month content
                    TabView(selection: $displayedMonth) {
                        ForEach(months, id: \.self) { month in
                            InlineMonthView(
                                month: month,
                                periodStart: currentStart,
                                periodEnd: currentEnd,
                                allPeriodDates: allPeriodDates,
                                currentSelectionDates: currentSelectionDates,
                                savedPeriods: periods,
                                onDayTap: handleDayTap
                            )
                            .padding(.horizontal, 24)
                            .tag(month)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 340)
                }
            }

            // Tutorial popup overlay
            if showTutorialPopup && tutorialStep != .complete {
                Color.black.opacity(0.001)  // Invisible tap target
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTutorialPopup = false
                        }
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Step indicator - using darker colors for accessibility (WCAG contrast)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    tutorialStep == .selectStart
                                        ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 8, height: 8)

                            Rectangle()
                                .fill(
                                    tutorialStep == .selectEnd
                                        ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 20, height: 2)

                            Circle()
                                .fill(
                                    tutorialStep == .selectEnd
                                        ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.6)
                                )
                                .frame(width: 8, height: 8)
                        }
                        .accessibilityHidden(true)

                        Text(tutorialTitle)
                            .font(.raleway("Bold", size: 18, relativeTo: .headline))
                            .foregroundColor(DesignColors.text)
                            .accessibilityAddTraits(.isHeader)

                        Text(tutorialMessage)
                            .font(.raleway("Regular", size: 15, relativeTo: .body))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            .multilineTextAlignment(.center)

                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignColors.accentSecondary)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .opacity(pulseAnimation ? 0.85 : 1.0)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                            .onAppear {
                                if !reduceMotion { pulseAnimation = true }
                            }
                            .accessibilityHidden(true)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showTutorialPopup = false
                            }
                        } label: {
                            Text("Got it")
                                .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(DesignColors.accentWarm)
                                )
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Completion popup
            if showTutorialPopup && tutorialStep == .complete && periods.isEmpty && !hasSeenTutorial {
                Color.black.opacity(0.001)  // Invisible tap target
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTutorialPopup = false
                        }
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                            .accessibilityHidden(true)

                        Text("Period marked!")
                            .font(.raleway("Bold", size: 20, relativeTo: .title2))
                            .foregroundColor(DesignColors.text)
                            .accessibilityAddTraits(.isHeader)

                        Text("\(currentDuration) days selected")
                            .font(.raleway("Regular", size: 15, relativeTo: .body))
                            .foregroundColor(DesignColors.text.opacity(0.7))

                        Text("Do you remember previous periods?")
                            .font(.raleway("Regular", size: 14, relativeTo: .body))
                            .foregroundColor(DesignColors.text.opacity(0.6))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button {
                                confirmCurrentPeriod()
                                withAnimation {
                                    showTutorialPopup = false
                                }
                            } label: {
                                Text("Add more")
                                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                                    .foregroundColor(DesignColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .strokeBorder(DesignColors.accent, lineWidth: 1.5)
                                    )
                            }

                            Button {
                                withAnimation {
                                    showTutorialPopup = false
                                }
                            } label: {
                                Text("Continue")
                                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(DesignColors.accent)
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
