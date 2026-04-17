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
        let totalPeriods = periods.count + (currentEnd != nil ? 1 : 0)

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

// MARK: - Inline Month View

private struct InlineMonthView: View {
    let month: Date
    let periodStart: Date?
    let periodEnd: Date?
    let allPeriodDates: Set<Date>
    let currentSelectionDates: Set<Date>
    let savedPeriods: [InlinePeriodCalendarPage.Period]
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        // Pad to 42 cells (6 rows) for consistent height
        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    private func isInPeriod(_ date: Date) -> Bool {
        allPeriodDates.contains(calendar.startOfDay(for: date))
    }

    private func isCurrentSelection(_ date: Date) -> Bool {
        currentSelectionDates.contains(calendar.startOfDay(for: date))
    }

    private func isStartDate(_ date: Date) -> Bool {
        if let start = periodStart, calendar.isDate(date, inSameDayAs: start) {
            return true
        }
        // Check saved periods
        for period in savedPeriods {
            if calendar.isDate(date, inSameDayAs: period.start) {
                return true
            }
        }
        return false
    }

    private func isEndDate(_ date: Date) -> Bool {
        if let end = periodEnd, calendar.isDate(date, inSameDayAs: end) {
            return true
        }
        // Check saved periods
        for period in savedPeriods {
            if calendar.isDate(date, inSameDayAs: period.end) {
                return true
            }
        }
        return false
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        date > Date()
    }

    var body: some View {
        VStack(spacing: 12) {
            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(height: 24)
                        .accessibilityHidden(true)
                }
            }

            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        InlineDayCell(
                            date: date,
                            isInPeriod: isInPeriod(date),
                            isCurrentSelection: isCurrentSelection(date),
                            isStartDate: isStartDate(date),
                            isEndDate: isEndDate(date),
                            isToday: isToday(date),
                            isFuture: isFuture(date),
                            onTap: { onDayTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }
}

private struct InlineDayCell: View {
    let date: Date
    let isInPeriod: Bool
    let isCurrentSelection: Bool
    let isStartDate: Bool
    let isEndDate: Bool
    let isToday: Bool
    let isFuture: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayAccessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        var label = formatter.string(from: date)
        if isToday { label = "Today, " + label }
        if isInPeriod { label += ". Period day" }
        if isStartDate { label += ". Period start" }
        if isEndDate { label += ". Period end" }
        if isFuture { label += ". Future date, disabled" }
        return label
    }

    var body: some View {
        Button(action: {
            if !isFuture {
                onTap()
            }
        }) {
            VStack(spacing: 2) {
                ZStack {
                    // Period highlight background
                    if isInPeriod {
                        if isStartDate || isEndDate {
                            Circle()
                                .fill(isCurrentSelection ? DesignColors.accentWarm : DesignColors.roseTaupe)
                        } else {
                            // Middle days - use circles
                            Circle()
                                .fill(
                                    isCurrentSelection
                                        ? DesignColors.accentWarm.opacity(0.4) : DesignColors.roseTaupeLight
                                )
                        }
                    } else if isToday {
                        Circle()
                            .strokeBorder(DesignColors.accentWarm, lineWidth: 1.5)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.raleway(isStartDate || isEndDate ? "Bold" : "Medium", size: 16, relativeTo: .body))
                        .foregroundColor(dayTextColor)
                }
                .frame(width: 40, height: 40)

                // "Today" label
                if isToday {
                    Text("today")
                        .font(.raleway("Medium", size: 9, relativeTo: .caption2))
                        .foregroundColor(DesignColors.accentWarm)
                }
            }
        }
        .disabled(isFuture)
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel)
        .accessibilityAddTraits(isInPeriod ? [.isSelected, .isButton] : [.isButton])
    }

    private var dayTextColor: Color {
        if isFuture {
            return DesignColors.text.opacity(0.3)
        } else if isStartDate || isEndDate {
            return .white
        } else if isInPeriod {
            return DesignColors.text
        } else {
            return DesignColors.text
        }
    }
}

// MARK: - Inline Period Calendar

private struct InlinePeriodCalendar: View {
    @Binding var selectedDate: Date
    let periodDuration: Int

    private let calendar = Calendar.current
    @State private var displayedMonth = Date()

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func isInPeriod(_ date: Date) -> Bool {
        guard
            let startOfSelected = calendar.date(
                from: calendar.dateComponents([.year, .month, .day], from: selectedDate)
            ),
            let startOfDate = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date))
        else {
            return false
        }
        let daysDiff = calendar.dateComponents([.day], from: startOfSelected, to: startOfDate).day ?? 0
        return daysDiff >= 0 && daysDiff < periodDuration
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        date > Date()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: {
                    withAnimation {
                        displayedMonth =
                            calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(monthFormatter.string(from: displayedMonth))
                    .font(.raleway("SemiBold", size: 18, relativeTo: .headline))
                    .foregroundColor(DesignColors.text)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button(action: {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                }
                .accessibilityLabel("Next month")
            }
            .padding(.horizontal, 8)

            // Day headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.raleway("SemiBold", size: 12, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(height: 30)
                        .accessibilityHidden(true)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayButton(
                            date: date,
                            isSelected: isSelected(date),
                            isInPeriod: isInPeriod(date),
                            isToday: isToday(date),
                            isDisabled: isFuture(date)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal, 24)
        .onAppear {
            displayedMonth = selectedDate
        }
    }
}

private struct CalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isInPeriod: Bool
    let isToday: Bool
    let isDisabled: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    private var dayAccessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        var label = formatter.string(from: date)
        if isToday { label = "Today, " + label }
        if isSelected { label += ". Selected" }
        if isInPeriod { label += ". Period day" }
        if isDisabled { label += ". Disabled" }
        return label
    }

    var body: some View {
        Button(action: action) {
            Text("\(calendar.component(.day, from: date))")
                .font(.raleway(isSelected ? "Bold" : "Medium", size: 16, relativeTo: .body))
                .foregroundColor(textColor)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .fill(DesignColors.accent)
                    } else if isInPeriod {
                        Circle()
                            .fill(DesignColors.periodPinkLight)
                    } else if isToday {
                        Circle()
                            .strokeBorder(DesignColors.accent, lineWidth: 1.5)
                    }
                }
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private var textColor: Color {
        if isDisabled {
            return DesignColors.text.opacity(0.3)
        } else if isSelected {
            return .white
        } else if isInPeriod {
            return DesignColors.text
        } else {
            return DesignColors.text
        }
    }
}

// MARK: - Period Calendar Sheet (Flo-style)

struct PeriodCalendarSheet: View {
    @Binding var selectedDate: Date
    @Binding var periodDuration: Int
    @Binding var isPresented: Bool

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

    // Current selection state
    @State private var currentStart: Date? = nil
    @State private var currentEnd: Date? = nil

    // Tutorial steps
    enum TutorialStep {
        case selectStart
        case selectEnd
        case complete
    }
    @State private var tutorialStep: TutorialStep = .selectStart
    @State private var hasSeenTutorial: Bool = false
    @State private var showTutorialPopup: Bool = true
    @State private var pulseAnimation: Bool = false
    @State private var hasSaved: Bool = false
    @State private var showAddMorePrompt: Bool = false

    private let calendar = Calendar.current

    init(selectedDate: Binding<Date>, periodDuration: Binding<Int>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._periodDuration = periodDuration
        self._isPresented = isPresented
    }

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

    // All period dates including saved periods and current selection
    private var allPeriodDates: Set<Date> {
        var dates: Set<Date> = []

        // Add all saved periods
        for period in periods {
            var current = period.start
            while current <= period.end {
                dates.insert(calendar.startOfDay(for: current))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }

        // Add current selection
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

    // Current selection dates only
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

    private var canSave: Bool {
        (currentStart != nil && currentEnd != nil && currentDuration >= 1) || !periods.isEmpty
    }

    private var mostRecentPeriod: Period? {
        periods.max(by: { $0.start < $1.start })
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
                }

            case .complete:
                // Start new selection
                currentStart = tappedDate
                currentEnd = nil
                tutorialStep = .selectEnd
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func confirmCurrentPeriod() {
        guard let start = currentStart, let end = currentEnd else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            periods.append(Period(start: start, end: end))
            currentStart = nil
            currentEnd = nil
            tutorialStep = .selectStart
            showAddMorePrompt = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func saveSelection() {
        // Add current selection to periods if complete
        if let start = currentStart, let end = currentEnd {
            periods.append(Period(start: start, end: end))
        }

        // Use most recent period for the binding
        if let recent = periods.max(by: { $0.start < $1.start }) {
            selectedDate = recent.start
            periodDuration = min(max(recent.duration, 2), 10)
        }

        hasSaved = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTutorialPopup = false
            showAddMorePrompt = false
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func closeSheet() {
        // Auto-save when closing
        if let start = currentStart, let end = currentEnd {
            periods.append(Period(start: start, end: end))
        }

        // Update bindings with most recent period
        if let recent = periods.max(by: { $0.start < $1.start }) {
            selectedDate = recent.start
            periodDuration = min(max(recent.duration, 2), 10)
        }

        isPresented = false
    }

    private func getSubtitleText() -> String {
        let totalPeriods = periods.count + (currentEnd != nil ? 1 : 0)

        if hasSaved {
            if totalPeriods > 0 {
                return "\(totalPeriods) period\(totalPeriods == 1 ? "" : "s") marked • Tap to add more"
            }
            return "Tap to mark your period days"
        } else {
            switch tutorialStep {
            case .selectStart:
                if periods.isEmpty {
                    return "Tap to mark your period days"
                } else {
                    return "\(periods.count) period\(periods.count == 1 ? "" : "s") added • Add more?"
                }
            case .selectEnd:
                return "Now tap the last day"
            case .complete:
                return "\(currentDuration) days selected"
            }
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
        case .complete: return "Your period is \(currentDuration) days. Tap Done to save."
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom Header
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Header content
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(periods.isEmpty && currentStart == nil ? "Select your period" : "Your periods")
                                .font(.raleway("Bold", size: 20, relativeTo: .title2))
                                .foregroundColor(DesignColors.text)
                                .accessibilityAddTraits(.isHeader)

                            Text(getSubtitleText())
                                .font(.raleway("Regular", size: 14, relativeTo: .body))
                                .foregroundColor(DesignColors.text.opacity(0.6))
                        }

                        Spacer()

                        // Close button - always visible
                        Button {
                            closeSheet()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignColors.text.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                )
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Period info display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if !periods.isEmpty {
                                Text("\(periods.count) period\(periods.count == 1 ? "" : "s") saved")
                                    .font(.raleway("Medium", size: 14, relativeTo: .body))
                                    .foregroundColor(DesignColors.text.opacity(0.7))
                            }

                            if currentDuration > 0 {
                                Text("Current: \(currentDuration) days")
                                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                                    .foregroundColor(DesignColors.accent)
                            } else if periods.isEmpty {
                                Text("No periods selected yet")
                                    .font(.raleway("Regular", size: 14, relativeTo: .body))
                                    .foregroundColor(DesignColors.text.opacity(0.4))
                            }
                        }

                        Spacer()

                        // Confirm current period button - add to list
                        if tutorialStep == .complete && currentStart != nil && currentEnd != nil {
                            Button {
                                confirmCurrentPeriod()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .accessibilityHidden(true)
                                    Text("Add")
                                        .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(DesignColors.accent)
                                )
                            }
                            .accessibilityLabel("Add period")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider()
                }
                .background(Color(UIColor.systemGroupedBackground))

                // Calendar content
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 32) {
                            ForEach(months, id: \.self) { month in
                                MonthView(
                                    month: month,
                                    periodStart: currentStart,
                                    periodEnd: currentEnd,
                                    periodDates: allPeriodDates,
                                    currentSelectionDates: currentSelectionDates,
                                    tutorialStep: tutorialStep,
                                    onDayTap: handleDayTap
                                )
                                .id(month)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .onAppear {
                        // Scroll to current month
                        let currentMonth = calendar.startOfMonth(for: Date())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentMonth, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))

            // Tutorial popup overlay
            if showTutorialPopup && tutorialStep != .complete {
                VStack {
                    Spacer()

                    // Tutorial card
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

                        Text(tutorialTitle)
                            .font(.raleway("Bold", size: 18, relativeTo: .headline))
                            .foregroundColor(DesignColors.text)
                            .accessibilityAddTraits(.isHeader)

                        Text(tutorialMessage)
                            .font(.raleway("Regular", size: 15, relativeTo: .body))
                            .foregroundColor(DesignColors.text.opacity(0.7))
                            .multilineTextAlignment(.center)

                        // Animated hand icon
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignColors.accentSecondary)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .opacity(pulseAnimation ? 0.85 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                            .onAppear {
                                pulseAnimation = true
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
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // First period complete popup - ask to add more or save
            if showTutorialPopup && tutorialStep == .complete && !hasSaved && periods.isEmpty {
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
                                // Add current and allow more
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
                                closeSheet()
                            } label: {
                                Text("Done")
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
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Month View

private struct MonthView: View {
    let month: Date
    let periodStart: Date?
    let periodEnd: Date?
    let periodDates: Set<Date>
    let currentSelectionDates: Set<Date>
    let tutorialStep: PeriodCalendarSheet.TutorialStep
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    // Check if any period continues from previous month
    private var periodContinuesFromPrevious: Bool {
        let firstDayOfMonth = calendar.startOfMonth(for: month)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: firstDayOfMonth) else { return false }
        return periodDates.contains(calendar.startOfDay(for: dayBefore)) && periodDates.contains(firstDayOfMonth)
    }

    // Check if any period continues to next month
    private var periodContinuesToNext: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: month)) else {
            return false
        }
        guard let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { return false }
        return periodDates.contains(calendar.startOfDay(for: lastDayOfMonth)) && periodDates.contains(nextMonth)
    }

    // Count period days in this month
    private var periodDaysInMonth: Int {
        let firstDay = calendar.startOfMonth(for: month)
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) else { return 0 }

        return periodDates.filter { date in
            date >= firstDay && date < nextMonth
        }.count
    }

    private var daysInMonth: [Date?] {
        let firstDay = calendar.startOfMonth(for: month)
        var weekday = calendar.component(.weekday, from: firstDay)
        // Convert to Monday = 0 format
        weekday = (weekday + 5) % 7

        var days: [Date?] = []

        // Add empty slots for days before the first day
        for _ in 0..<weekday {
            days.append(nil)
        }

        // Add all days of the month
        let range = calendar.range(of: .day, in: .month, for: month)!
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month header with period indicators
            HStack(spacing: 8) {
                // Arrow from previous month
                if periodContinuesFromPrevious {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                        .accessibilityHidden(true)
                }

                Text(monthName)
                    .font(.raleway("SemiBold", size: 18, relativeTo: .headline))
                    .foregroundColor(DesignColors.text)
                    .accessibilityAddTraits(.isHeader)

                // Period days count badge
                if periodDaysInMonth > 0 {
                    Text("\(periodDaysInMonth)d")
                        .font(.raleway("Medium", size: 12, relativeTo: .caption))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignColors.accent)
                        )
                        .accessibilityLabel("\(periodDaysInMonth) period days this month")
                }

                // Arrow to next month
                if periodContinuesToNext {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignColors.accent)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)

            // Days grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let dayDate = calendar.startOfDay(for: date)
                        let isStart = periodStart.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                        let isEnd = periodEnd.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                        let isCurrentSelection = currentSelectionDates.contains(dayDate)
                        let isSavedPeriod = periodDates.contains(dayDate) && !isCurrentSelection

                        DayCell(
                            date: date,
                            isStartDay: isStart,
                            isEndDay: isEnd,
                            isPeriodDay: periodDates.contains(dayDate),
                            isCurrentSelection: isCurrentSelection,
                            isSavedPeriod: isSavedPeriod,
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
                            tutorialStep: tutorialStep,
                            onTap: {
                                onDayTap(date)
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isStartDay: Bool
    let isEndDay: Bool
    let isPeriodDay: Bool
    let isCurrentSelection: Bool
    let isSavedPeriod: Bool
    let isToday: Bool
    let isFuture: Bool
    let tutorialStep: PeriodCalendarSheet.TutorialStep
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var dayAccessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        var label = formatter.string(from: date)
        if isToday { label = "Today, " + label }
        if isStartDay { label += ". Period start" }
        if isEndDay { label += ". Period end" }
        if isPeriodDay && !isStartDay && !isEndDay { label += ". Period day" }
        if isSavedPeriod { label += ". Saved" }
        if isFuture { label += ". Future date, disabled" }
        return label
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background for period days
                if isPeriodDay {
                    Circle()
                        .fill(isCurrentSelection ? DesignColors.accent : DesignColors.accent.opacity(0.6))
                        .scaleEffect(isStartDay || isEndDay ? 1.0 : 0.85)
                } else if isToday {
                    Circle()
                        .strokeBorder(DesignColors.accent, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }

                // Highlight ring for start/end days of current selection
                if isStartDay || isEndDay {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .scaleEffect(0.9)
                }

                // Checkmark for saved periods
                if isSavedPeriod {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(DesignColors.accent)
                                        .frame(width: 12, height: 12)
                                )
                        }
                    }
                    .frame(width: 44, height: 44)
                    .offset(x: -4, y: -4)
                    .accessibilityHidden(true)
                }

                // Day number
                Text(dayNumber)
                    .font(.raleway(isStartDay || isEndDay ? "Bold" : "Medium", size: 16, relativeTo: .body))
                    .foregroundColor(
                        isFuture
                            ? DesignColors.text.opacity(0.3)
                            : isPeriodDay ? .white : isToday ? DesignColors.accent : DesignColors.text
                    )
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(dayAccessibilityLabel)
        .accessibilityAddTraits(isPeriodDay ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
