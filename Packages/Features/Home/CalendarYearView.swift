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
                VStack(spacing: 16) {
                    ForEach(Self.allMonths, id: \.year) { yearData in
                        VStack(spacing: 8) {
                            Text(String(yearData.year))
                                .font(.raleway("Bold", size: 22, relativeTo: .title2))
                                .foregroundStyle(DesignColors.text)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .id("year-\(yearData.year)")

                            VStack(spacing: 6) {
                                ForEach(0..<4, id: \.self) { row in
                                    HStack(spacing: 6) {
                                        ForEach(0..<3, id: \.self) { col in
                                            let idx = row * 3 + col
                                            if idx < yearData.months.count {
                                                let month = yearData.months[idx]
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
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
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

    private var monthName: String {
        DateFormatter.shortMonth.string(from: month)
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
        let baseColor: Color?    // nil = no circle
        let fillOpacity: CGFloat
        let dashed: Bool
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

                    let periodCol = CyclePhase.menstrual.orbitColor
                    let fertileCol = DesignColors.accentWarm

                    let baseColor: Color?
                    let fillOpacity: CGFloat
                    let dashed: Bool
                    if isConfirmed {
                        baseColor = periodCol; fillOpacity = 0.75; dashed = false
                    } else if isPredictedPeriod {
                        baseColor = periodCol; fillOpacity = 0.18; dashed = true
                    } else if isOvulation {
                        baseColor = fertileCol; fillOpacity = 0.45; dashed = false
                    } else if isFertile {
                        baseColor = fertileCol; fillOpacity = 0.35; dashed = false
                    } else {
                        baseColor = nil; fillOpacity = 0; dashed = false
                    }

                    let textColor: Color
                    if isConfirmed { textColor = .white }
                    else if isPredictedPeriod { textColor = periodCol }
                    else if isOvulation || isFertile { textColor = .white }
                    else if isToday { textColor = DesignColors.accentWarm }
                    else { textColor = DesignColors.text.opacity(0.55) }

                    week.append(DaySlot(
                        day: d, baseColor: baseColor, fillOpacity: fillOpacity,
                        dashed: dashed, textColor: textColor, isBold: isToday || isConfirmed
                    ))
                    day += 1
                }
            }
            rows.append(week)
        }
        return rows
    }

    // MARK: - Body

    private var rowCount: Int {
        cachedGrid.count
    }

    var body: some View {
        let headerH: CGFloat = 20
        let cellSize: CGFloat = 14
        let spacing: CGFloat = 2
        let gridH = CGFloat(rowCount) * (cellSize + spacing)
        let totalH = headerH + gridH + 12

        Canvas { ctx, size in
            let padX: CGFloat = 4
            let padY: CGFloat = 6
            let availW = size.width - padX * 2
            let colW = availW / 7

            // Month name
            let nameFont = UIFont.raleway(isCurrentMonth ? "Bold" : "SemiBold", size: 14, textStyle: .subheadline)
            let nameColor = isCurrentMonth ? UIColor(DesignColors.accentWarm) : UIColor(DesignColors.text)
            let nameStr = NSAttributedString(string: monthName, attributes: [.font: nameFont, .foregroundColor: nameColor])
            let nameSize = nameStr.size()
            let nameX = (size.width - nameSize.width) / 2
            ctx.draw(Text(monthName).font(.raleway(isCurrentMonth ? "Bold" : "SemiBold", size: 14, relativeTo: .subheadline)).foregroundColor(isCurrentMonth ? DesignColors.accentWarm : DesignColors.text), at: CGPoint(x: size.width / 2, y: padY + 8), anchor: .center)

            let gridTop = padY + headerH

            // Draw grid
            for (rowIdx, week) in cachedGrid.enumerated() {
                for col in 0..<7 {
                    guard let slot = week[col] else { continue }
                    let cx = padX + CGFloat(col) * colW + colW / 2
                    let cy = gridTop + CGFloat(rowIdx) * (cellSize + spacing) + cellSize / 2
                    let r = cellSize / 2

                    // Glass circle
                    if let base = slot.baseColor {
                        let rect = CGRect(x: cx - r, y: cy - r, width: cellSize, height: cellSize)

                        // Gradient fill (lighter top → base bottom)
                        let topColor = base.opacity(min(slot.fillOpacity + 0.15, 1))
                        let botColor = base.opacity(slot.fillOpacity)
                        ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
                            Gradient(colors: [topColor, botColor]),
                            startPoint: CGPoint(x: cx, y: cy - r),
                            endPoint: CGPoint(x: cx, y: cy + r)
                        ))

                        // Top shine
                        let shineRect = rect.insetBy(dx: 2, dy: 2).offsetBy(dx: 0, dy: -1)
                        ctx.fill(Path(ellipseIn: shineRect), with: .linearGradient(
                            Gradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0)]),
                            startPoint: CGPoint(x: cx, y: shineRect.minY),
                            endPoint: CGPoint(x: cx, y: shineRect.midY)
                        ))

                        // Border
                        let borderStyle = slot.dashed
                            ? StrokeStyle(lineWidth: 0.5, dash: [2, 2])
                            : StrokeStyle(lineWidth: 0.5)
                        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.25, dy: 0.25)),
                                   with: .color(base.opacity(min(slot.fillOpacity + 0.2, 0.8))),
                                   style: borderStyle)
                    }

                    // Day number
                    let font: Font = .system(size: 10, weight: slot.isBold ? .bold : .medium, design: .rounded)
                    ctx.draw(Text("\(slot.day)").font(font).foregroundColor(slot.textColor), at: CGPoint(x: cx, y: cy), anchor: .center)
                }
            }

            // Border
            let borderColor = isCurrentMonth ? DesignColors.accentWarm.opacity(0.3) : Color.white.opacity(0.08)
            let borderWidth: CGFloat = isCurrentMonth ? 1 : 0.5
            let borderRect = CGRect(origin: .zero, size: size)
            let borderPath = Path(roundedRect: borderRect, cornerRadius: 12, style: .continuous)
            ctx.stroke(borderPath, with: .color(borderColor), lineWidth: borderWidth)
        }
        .frame(height: totalH)
    }
}
