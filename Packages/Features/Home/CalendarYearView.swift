import SwiftUI

// MARK: - Year Overview

struct YearOverviewView: View {
    let periodDays: Set<String>
    let predictedPeriodDays: Set<String>
    let fertileDays: [String: FertilityLevel]
    let ovulationDays: Set<String>
    let cycleLength: Int
    let menstrualStatus: MenstrualStatusResponse?
    var onMonthTapped: (Date) -> Void

    private let cal = Calendar.current
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    private var periodIsLate: Bool {
        menstrualStatus?.nextPrediction?.isLate == true
    }

    private var lateWindowKeys: Set<String> {
        guard periodIsLate,
              let pred = menstrualStatus?.nextPrediction?.predictedDate else { return [] }
        let startOfPred = cal.startOfDay(for: pred)
        var keys = Set<String>()
        for offset in -1..<cycleLength {
            if let d = cal.date(byAdding: .day, value: offset, to: startOfPred) {
                let key = CalendarFeature.dateKey(d)
                if predictedPeriodDays.contains(key) {
                    keys.insert(key)
                }
            }
        }
        return keys
    }

    private static let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return [currentYear - 1, currentYear, currentYear + 1]
    }()

    private static let allMonths: [(year: Int, months: [Date])] = {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        return [currentYear - 1, currentYear, currentYear + 1].map { year in
            let months = (1...12).compactMap { month -> Date? in
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                comps.day = 1
                return cal.date(from: comps)
            }
            return (year: year, months: months)
        }
    }()

    var body: some View {
        let lateKeys = lateWindowKeys
        let isLate = periodIsLate

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(Self.allMonths, id: \.year) { yearData in
                        VStack(spacing: 8) {
                            Text(String(yearData.year))
                                .font(.custom("Raleway-Bold", size: 22))
                                .foregroundStyle(DesignColors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("year-\(yearData.year)")

                            LazyVGrid(columns: gridColumns, spacing: 6) {
                                ForEach(yearData.months, id: \.self) { month in
                                    Button {
                                        onMonthTapped(month)
                                    } label: {
                                        MiniMonthCell(
                                            month: month,
                                            periodDays: periodDays,
                                            predictedPeriodDays: predictedPeriodDays,
                                            fertileDays: fertileDays,
                                            ovulationDays: ovulationDays,
                                            isLate: isLate,
                                            lateWindowKeys: lateKeys
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .onAppear {
                let currentYear = cal.component(.year, from: Date())
                DispatchQueue.main.async {
                    proxy.scrollTo("year-\(currentYear)", anchor: .top)
                }
            }
        }
    }
}

// MARK: - Mini Month Cell

struct MiniMonthCell: View {
    let month: Date
    let periodDays: Set<String>
    let predictedPeriodDays: Set<String>
    let fertileDays: [String: FertilityLevel]
    let ovulationDays: Set<String>
    var isLate: Bool = false
    var lateWindowKeys: Set<String> = []

    let cachedGrid: [[DaySlot?]]

    private let cal = Calendar.current

    private static let monthNameFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt
    }()

    private var monthName: String {
        Self.monthNameFormatter.string(from: month)
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        return cal.component(.month, from: month) == cal.component(.month, from: now)
            && cal.component(.year, from: month) == cal.component(.year, from: now)
    }

    private var yearMonth: String {
        CalendarView.monthIdFormatter.string(from: month)
    }

    // MARK: - Pre-computed day data

    struct DaySlot: Sendable {
        let day: Int
        let fill: Color
        let dashColor: Color?
        let textColor: Color
        let isBold: Bool
    }

    // MARK: - Init

    init(
        month: Date,
        periodDays: Set<String>,
        predictedPeriodDays: Set<String>,
        fertileDays: [String: FertilityLevel],
        ovulationDays: Set<String>,
        isLate: Bool = false,
        lateWindowKeys: Set<String> = []
    ) {
        self.month = month
        self.periodDays = periodDays
        self.predictedPeriodDays = predictedPeriodDays
        self.fertileDays = fertileDays
        self.ovulationDays = ovulationDays
        self.isLate = isLate
        self.lateWindowKeys = lateWindowKeys
        self.cachedGrid = Self.computeGrid(
            month: month,
            periodDays: periodDays,
            predictedPeriodDays: predictedPeriodDays,
            fertileDays: fertileDays,
            ovulationDays: ovulationDays,
            lateWindowKeys: lateWindowKeys
        )
    }

    // MARK: - Grid computation

    private static func computeGrid(
        month: Date,
        periodDays: Set<String>,
        predictedPeriodDays: Set<String>,
        fertileDays: [String: FertilityLevel],
        ovulationDays: Set<String>,
        lateWindowKeys: Set<String>
    ) -> [[DaySlot?]] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: month)
        comps.day = 1
        guard let first = cal.date(from: comps) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let offset = (weekday + 5) % 7
        let daysCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30

        let now = Date()
        let isCurrentMonth = cal.component(.month, from: month) == cal.component(.month, from: now)
            && cal.component(.year, from: month) == cal.component(.year, from: now)
        let today = cal.component(.day, from: now)

        let fmt = CalendarView.monthIdFormatter
        let ym = fmt.string(from: month)

        var rows: [[DaySlot?]] = []
        var day = 1
        for row in 0..<6 {
            var week: [DaySlot?] = []
            for col in 0..<7 {
                let slot = row * 7 + col
                if slot < offset || day > daysCount {
                    week.append(nil)
                } else {
                    let d = day
                    let key = "\(ym)-\(String(format: "%02d", d))"
                    let isInLateWindow = lateWindowKeys.contains(key)
                    let isPeriod = periodDays.contains(key)
                    let isPredicted = predictedPeriodDays.contains(key)
                    let isConfirmed = isPeriod && !isPredicted
                    let isFertile = fertileDays[key] != nil && !isInLateWindow
                    let isOvulation = ovulationDays.contains(key) && !isInLateWindow
                    let isToday = isCurrentMonth && d == today
                    let isPredictedPeriod = isPredicted && isPeriod && !isConfirmed

                    let fertileColor = CyclePhase.ovulatory.orbitColor

                    let fill: Color
                    if isConfirmed { fill = CyclePhase.menstrual.orbitColor }
                    else if isPredictedPeriod { fill = CyclePhase.menstrual.orbitColor.opacity(0.4) }
                    else if isOvulation { fill = fertileColor.opacity(0.6) }
                    else if isFertile { fill = fertileColor.opacity(0.4) }
                    else { fill = .clear }

                    let textColor: Color
                    if isConfirmed { textColor = .white }
                    else if isOvulation { textColor = .white.opacity(0.9) }
                    else if isPredictedPeriod { textColor = CyclePhase.menstrual.orbitColor }
                    else if isFertile { textColor = fertileColor.opacity(0.9) }
                    else if isToday { textColor = DesignColors.accentWarm }
                    else { textColor = DesignColors.text.opacity(0.55) }

                    let isDashed = isPredictedPeriod || (isFertile && !isOvulation)
                    let dashColor: Color? = isDashed
                        ? (isPredictedPeriod
                            ? CyclePhase.menstrual.orbitColor.opacity(0.6)
                            : fertileColor.opacity(0.6))
                        : nil

                    week.append(DaySlot(
                        day: d, fill: fill, dashColor: dashColor,
                        textColor: textColor, isBold: isToday || isConfirmed
                    ))
                    day += 1
                }
            }
            rows.append(week)
        }
        return rows
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 2) {
            Text(monthName)
                .font(.custom(isCurrentMonth ? "Raleway-Bold" : "Raleway-SemiBold", size: 14))
                .foregroundStyle(isCurrentMonth ? DesignColors.accentWarm : DesignColors.text)

            VStack(spacing: 2) {
                ForEach(Array(cachedGrid.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 1) {
                        ForEach(0..<7, id: \.self) { col in
                            if let slot = week[col] {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .overlay {
                                        ZStack {
                                            if slot.fill != .clear {
                                                Circle().fill(slot.fill)
                                            }
                                            if let dash = slot.dashColor {
                                                Circle()
                                                    .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                                    .foregroundStyle(dash)
                                            }
                                            Text("\(slot.day)")
                                                .font(.system(size: 10, weight: slot.isBold ? .bold : .medium, design: .rounded))
                                                .foregroundStyle(slot.textColor)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                        }
                                    }
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isCurrentMonth
                                ? DesignColors.accentWarm.opacity(0.3)
                                : Color.white.opacity(0.08),
                            lineWidth: isCurrentMonth ? 1 : 0.5
                        )
                }
        }
        .drawingGroup()
    }
}
