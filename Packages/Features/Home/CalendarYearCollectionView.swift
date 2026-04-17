import SwiftUI
import UIKit

// MARK: - Year Collection View (UIKit + CoreGraphics)

struct CalendarYearCollectionView: UIViewRepresentable {
    let periodDays: Set<String>
    let predictedPeriodDays: Set<String>
    let fertileDays: [String: FertilityLevel]
    let ovulationDays: Set<String>
    let cycleLength: Int
    let menstrualStatus: MenstrualStatusResponse?
    let onMonthTapped: (Date) -> Void
    let onZoomCompleted: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> YearCollectionContainer {
        let container = YearCollectionContainer()
        container.onMonthTapped = { [self] date in onMonthTapped(date) }
        container.onZoomCompleted = { [self] in onZoomCompleted() }
        container.configure(with: self)
        return container
    }

    func updateUIView(_ view: YearCollectionContainer, context: Context) {
        context.coordinator.parent = self
        view.configure(with: self)
    }

    class Coordinator {
        var parent: CalendarYearCollectionView
        init(parent: CalendarYearCollectionView) { self.parent = parent }
    }
}

// MARK: - Year Collection Container

final class YearCollectionContainer: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var collectionView: UICollectionView!
    private var didInitialScroll = false
    var onMonthTapped: ((Date) -> Void)?
    var onZoomCompleted: (() -> Void)?

    // Data
    private var periodDays: Set<String> = []
    private var predictedPeriodDays: Set<String> = []
    private var fertileDays: [String: FertilityLevel] = [:]
    private var ovulationDays: Set<String> = []
    private var cycleLength: Int = 28
    private var isLate: Bool = false
    private var lateWindowKeys: Set<String> = []

    private static let allMonths: [Date] = {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        var months: [Date] = []
        for year in [currentYear - 1, currentYear, currentYear + 1] {
            for m in 1...12 {
                var c = DateComponents()
                c.year = year; c.month = m; c.day = 1
                if let d = cal.date(from: c) { months.append(d) }
            }
        }
        return months
    }()

    private let cal = Calendar.current

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 20, right: 16)
        layout.headerReferenceSize = CGSize(width: 0, height: 40)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MiniMonthCGCell.self, forCellWithReuseIdentifier: "mini")
        collectionView.register(YearHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collectionView.contentInsetAdjustmentBehavior = .never

        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(with rep: CalendarYearCollectionView) {
        let needsReload = periodDays != rep.periodDays
            || predictedPeriodDays != rep.predictedPeriodDays
            || cycleLength != rep.cycleLength

        periodDays = rep.periodDays
        predictedPeriodDays = rep.predictedPeriodDays
        fertileDays = rep.fertileDays
        ovulationDays = rep.ovulationDays
        cycleLength = rep.cycleLength
        isLate = rep.menstrualStatus?.nextPrediction?.isLate == true
        lateWindowKeys = computeLateKeys(rep)
        onMonthTapped = rep.onMonthTapped

        if needsReload {
            collectionView.reloadData()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !didInitialScroll && collectionView.frame.width > 0 {
            didInitialScroll = true
            let currentYear = cal.component(.year, from: Date())
            let section = currentYear - (currentYear - 1) // index 1 = current year
            let currentMonth = cal.component(.month, from: Date()) - 1
            let ip = IndexPath(item: currentMonth, section: section)
            collectionView.layoutIfNeeded()
            collectionView.scrollToItem(at: ip, at: .centeredVertically, animated: false)
        }
    }

    private func computeLateKeys(_ rep: CalendarYearCollectionView) -> Set<String> {
        guard isLate, let pred = rep.menstrualStatus?.nextPrediction?.predictedDate else { return [] }
        let start = cal.startOfDay(for: pred)
        var keys = Set<String>()
        for offset in -1..<cycleLength {
            if let d = cal.date(byAdding: .day, value: offset, to: start) {
                let key = CalendarFeature.dateKey(d)
                if predictedPeriodDays.contains(key) { keys.insert(key) }
            }
        }
        return keys
    }

    // MARK: - DataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int { 3 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 12 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "mini", for: indexPath) as! MiniMonthCGCell
        let month = Self.allMonths[indexPath.section * 12 + indexPath.item]
        cell.configure(month: month, periodDays: periodDays, predictedPeriodDays: predictedPeriodDays, fertileDays: fertileDays, ovulationDays: ovulationDays, lateWindowKeys: lateWindowKeys)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! YearHeaderView
        let currentYear = cal.component(.year, from: Date())
        header.configure(year: currentYear - 1 + indexPath.section)
        return header
    }

    // MARK: - Layout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets: CGFloat = 16 + 16
        let spacing: CGFloat = 10
        let w = (collectionView.bounds.width - insets - spacing) / 2
        return CGSize(width: w, height: w * 1.05)
    }

    // MARK: - Selection

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let month = Self.allMonths[indexPath.section * 12 + indexPath.item]
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        onMonthTapped?(month)
        onZoomCompleted?()
    }
}

// MARK: - Year Header

private final class YearHeaderView: UICollectionReusableView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = UIFont.raleway("Bold", size: 22, textStyle: .title2)
        label.textColor = UIColor(DesignColors.text)
        label.textAlignment = .center
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(year: Int) { label.text = String(year) }
}

// MARK: - Mini Month CG Cell

final class MiniMonthCGCell: UICollectionViewCell {
    private let drawView = MiniMonthDrawView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(drawView)
        drawView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            drawView.topAnchor.constraint(equalTo: contentView.topAnchor),
            drawView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            drawView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            drawView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(month: Date, periodDays: Set<String>, predictedPeriodDays: Set<String>, fertileDays: [String: FertilityLevel], ovulationDays: Set<String>, lateWindowKeys: Set<String>) {
        drawView.configure(month: month, periodDays: periodDays, predictedPeriodDays: predictedPeriodDays, fertileDays: fertileDays, ovulationDays: ovulationDays, lateWindowKeys: lateWindowKeys)
    }
}

// MARK: - CoreGraphics Mini Month

private final class MiniMonthDrawView: UIView {
    private var month = Date()
    private var grid: [[(day: Int, baseColor: UIColor?, fillOpacity: CGFloat, dashed: Bool, textColor: UIColor, isBold: Bool)?]] = []
    private var monthName = ""
    private var isCurrent = false

    private let cal = Calendar.current

    private let periodColor = UIColor(DesignColors.calendarPeriodGlyph)
    private let fertileColor = UIColor(DesignColors.calendarFertileGlyph)
    private let textColor = UIColor(DesignColors.calendarDayText).withAlphaComponent(0.55)
    private let accentWarm = UIColor(DesignColors.accentWarm)
    private let textMain = UIColor(DesignColors.text)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(month: Date, periodDays: Set<String>, predictedPeriodDays: Set<String>, fertileDays: [String: FertilityLevel], ovulationDays: Set<String>, lateWindowKeys: Set<String>) {
        self.month = month
        self.monthName = DateFormatter.shortMonth.string(from: month)
        let now = Date()
        self.isCurrent = cal.component(.month, from: month) == cal.component(.month, from: now) && cal.component(.year, from: month) == cal.component(.year, from: now)
        self.grid = Self.buildGrid(month: month, periodDays: periodDays, predictedPeriodDays: predictedPeriodDays, fertileDays: fertileDays, ovulationDays: ovulationDays, lateWindowKeys: lateWindowKeys, periodColor: periodColor, fertileColor: fertileColor, textColor: textColor, accentWarm: accentWarm, textMain: textMain, isCurrent: isCurrent)
        setNeedsDisplay()
    }

    private static func buildGrid(month: Date, periodDays: Set<String>, predictedPeriodDays: Set<String>, fertileDays: [String: FertilityLevel], ovulationDays: Set<String>, lateWindowKeys: Set<String>, periodColor: UIColor, fertileColor: UIColor, textColor: UIColor, accentWarm: UIColor, textMain: UIColor, isCurrent: Bool) -> [[(day: Int, baseColor: UIColor?, fillOpacity: CGFloat, dashed: Bool, textColor: UIColor, isBold: Bool)?]] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: month)
        comps.day = 1
        guard let first = cal.date(from: comps) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let offset = (weekday + 5) % 7
        let daysCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let today = cal.component(.day, from: Date())
        let fmt = CalendarView.monthIdFormatter
        let ym = fmt.string(from: month)

        var rows: [[(day: Int, baseColor: UIColor?, fillOpacity: CGFloat, dashed: Bool, textColor: UIColor, isBold: Bool)?]] = []
        var day = 1
        for row in 0..<6 {
            var week: [(day: Int, baseColor: UIColor?, fillOpacity: CGFloat, dashed: Bool, textColor: UIColor, isBold: Bool)?] = []
            for col in 0..<7 {
                let slot = row * 7 + col
                if slot < offset || day > daysCount {
                    week.append(nil)
                } else {
                    let d = day
                    let key = "\(ym)-\(String(format: "%02d", d))"
                    let isInLate = lateWindowKeys.contains(key)
                    let isPeriod = periodDays.contains(key)
                    let isPredicted = predictedPeriodDays.contains(key)
                    let isConfirmed = isPeriod && !isPredicted
                    let isFert = fertileDays[key] != nil && !isInLate
                    let isOv = ovulationDays.contains(key) && !isInLate
                    let isToday = isCurrent && d == today
                    let isPredPeriod = isPredicted && isPeriod && !isConfirmed

                    let base: UIColor?
                    let opacity: CGFloat
                    let dashed: Bool
                    if isConfirmed { base = periodColor; opacity = 0.75; dashed = false }
                    else if isPredPeriod { base = periodColor; opacity = 0.18; dashed = true }
                    else if isOv { base = fertileColor; opacity = 0.45; dashed = false }
                    else if isFert { base = fertileColor; opacity = 0.35; dashed = false }
                    else { base = nil; opacity = 0; dashed = false }

                    let tc: UIColor
                    if isConfirmed { tc = .white }
                    else if isPredPeriod { tc = periodColor }
                    else if isOv || isFert { tc = .white }
                    else if isToday { tc = accentWarm }
                    else { tc = textColor }

                    week.append((day: d, baseColor: base, fillOpacity: opacity, dashed: dashed, textColor: tc, isBold: isToday || isConfirmed))
                    day += 1
                }
            }
            rows.append(week)
            if day > daysCount { break }
        }
        return rows
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let padX: CGFloat = 6
        let padY: CGFloat = 6
        let headerH: CGFloat = 22
        let availW = rect.width - padX * 2
        let colW = availW / 7
        let gridH = rect.height - padY - headerH - 4
        let rowH = grid.isEmpty ? 14 : gridH / CGFloat(grid.count)
        let cellSize = min(rowH - 2, colW - 2)

        // Month name
        let nameFont = UIFont.raleway(isCurrent ? "Bold" : "SemiBold", size: 15, textStyle: .subheadline)
        let nameColor = isCurrent ? accentWarm : textMain
        let nameStr = NSAttributedString(string: monthName, attributes: [.font: nameFont, .foregroundColor: nameColor])
        let nameSize = nameStr.size()
        nameStr.draw(at: CGPoint(x: (rect.width - nameSize.width) / 2, y: padY))

        let gridTop = padY + headerH

        // Draw grid
        for (rowIdx, week) in grid.enumerated() {
            for col in 0..<7 {
                guard let slot = week[col] else { continue }
                let cx = padX + CGFloat(col) * colW + colW / 2
                let cy = gridTop + CGFloat(rowIdx) * rowH + rowH / 2
                let r = cellSize / 2
                let circleRect = CGRect(x: cx - r, y: cy - r, width: cellSize, height: cellSize)

                // Glass circle
                if let base = slot.baseColor {
                    ctx.saveGState()
                    let path = CGPath(ellipseIn: circleRect, transform: nil)
                    ctx.addPath(path)
                    ctx.clip()

                    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
                    base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)

                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let topC = UIColor(red: min(br + 0.15, 1), green: min(bg + 0.15, 1), blue: min(bb + 0.15, 1), alpha: slot.fillOpacity).cgColor
                    let botC = UIColor(red: br, green: bg, blue: bb, alpha: slot.fillOpacity).cgColor
                    if let grad = CGGradient(colorsSpace: colorSpace, colors: [topC, botC] as CFArray, locations: [0, 1]) {
                        ctx.drawLinearGradient(grad, start: CGPoint(x: cx, y: circleRect.minY), end: CGPoint(x: cx, y: circleRect.maxY), options: [])
                    }

                    // Top shine
                    let shineTop = UIColor.white.withAlphaComponent(0.35).cgColor
                    let shineBot = UIColor.white.withAlphaComponent(0).cgColor
                    if let shine = CGGradient(colorsSpace: colorSpace, colors: [shineTop, shineBot] as CFArray, locations: [0, 1]) {
                        ctx.drawLinearGradient(shine, start: CGPoint(x: cx, y: circleRect.minY + 1), end: CGPoint(x: cx, y: cy), options: [])
                    }
                    ctx.restoreGState()

                    // Border
                    ctx.setStrokeColor(UIColor(red: min(br + 0.1, 1), green: min(bg + 0.1, 1), blue: min(bb + 0.1, 1), alpha: min(slot.fillOpacity + 0.2, 0.8)).cgColor)
                    ctx.setLineWidth(0.5)
                    if slot.dashed { ctx.setLineDash(phase: 0, lengths: [2, 2]) }
                    ctx.strokeEllipse(in: circleRect.insetBy(dx: 0.25, dy: 0.25))
                    if slot.dashed { ctx.setLineDash(phase: 0, lengths: []) }
                }

                // Day number
                let font = UIFont.raleway(slot.isBold ? "Bold" : "Medium", size: 13, textStyle: .caption1)
                let str = NSAttributedString(string: "\(slot.day)", attributes: [.font: font, .foregroundColor: slot.textColor])
                let sz = str.size()
                str.draw(at: CGPoint(x: cx - sz.width / 2, y: cy - sz.height / 2))
            }
        }

        // Border around cell
        if isCurrent {
            ctx.setStrokeColor(accentWarm.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(1)
        } else {
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            ctx.setLineWidth(0.5)
        }
        let borderPath = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 12)
        ctx.addPath(borderPath.cgPath)
        ctx.strokePath()
    }
}
