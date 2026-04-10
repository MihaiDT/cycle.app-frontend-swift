import SwiftUI
import UIKit

// MARK: - UIKit Calendar Scroll (UITableView + CoreGraphics)

struct CalendarTableView: UIViewRepresentable {
    let months: [Date]
    let periodDays: Set<String>
    let predictedPeriodDays: Set<String>
    let fertileDays: [String: FertilityLevel]
    let ovulationDays: Set<String>
    let selectedDate: Date?
    let isLate: Bool
    let predictedDate: Date?
    let cycleLength: Int
    let loggedDays: [String: CalendarFeature.State.DayLog]
    let isEditingPeriod: Bool
    let editPeriodDays: Set<String>
    let onDaySelected: (Date) -> Void
    let onEditDayTapped: (Date) -> Void
    let initialMonth: Date
    var scrollTrigger: Int = 0
    var scrollTargetMonth: Date?
    var onCurrentMonthVisibilityChanged: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITableView {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(MonthCell.self, forCellReuseIdentifier: "m")
        tv.dataSource = context.coordinator
        tv.delegate = context.coordinator
        tv.separatorStyle = .none
        tv.backgroundColor = UIColor(DesignColors.background)
        tv.showsVerticalScrollIndicator = false
        tv.contentInsetAdjustmentBehavior = .never
        tv.contentInset = .zero
        return tv
    }

    func updateUIView(_ tv: UITableView, context: Context) {
        let old = context.coordinator.parent
        context.coordinator.parent = self

        // Initial scroll to current month
        if !context.coordinator.didInitialScroll {
            context.coordinator.didInitialScroll = true
            let fmt = CalendarView.monthIdFormatter
            let target = fmt.string(from: initialMonth)
            if let idx = months.firstIndex(where: { fmt.string(from: $0) == target }) {
                DispatchQueue.main.async {
                    tv.scrollToRow(at: IndexPath(row: idx, section: 0), at: .middle, animated: false)
                }
            }
        }

        // Programmatic scroll (Today button, year view tap) — trigger increments each tap
        if scrollTrigger != old.scrollTrigger, let target = scrollTargetMonth {
            let fmt = CalendarView.monthIdFormatter
            let targetStr = fmt.string(from: target)
            if let idx = months.firstIndex(where: { fmt.string(from: $0) == targetStr }) {
                tv.scrollToRow(at: IndexPath(row: idx, section: 0), at: .top, animated: false)
            }
        }

        // Reload when data changes
        if old.isEditingPeriod != isEditingPeriod {
            // Full reload on edit toggle — ensures all cells update
            tv.reloadData()
        } else if old.periodDays != periodDays || old.predictedPeriodDays != predictedPeriodDays
            || old.editPeriodDays != editPeriodDays
            || old.fertileDays != fertileDays || old.selectedDate != selectedDate {
            for cell in tv.visibleCells {
                if let mc = cell as? MonthCell, let ip = tv.indexPath(for: mc) {
                    mc.configure(month: months[ip.row], parent: self)
                }
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: CalendarTableView
        var didInitialScroll = false
        var currentMonthIndex: Int = -1

        init(parent: CalendarTableView) {
            self.parent = parent
            let fmt = CalendarView.monthIdFormatter
            let today = fmt.string(from: Date())
            self.currentMonthIndex = parent.months.firstIndex(where: { fmt.string(from: $0) == today }) ?? -1
        }

        func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
            parent.months.count
        }

        func tableView(_ tv: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            let month = parent.months[indexPath.row]
            let rows = MonthGridRenderer.rowCount(for: month)
            // header(36) + grid(rows * 64) + bottom padding(28)
            return 36 + CGFloat(rows) * 64 + 28
        }

        func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tv.dequeueReusableCell(withIdentifier: "m", for: indexPath) as! MonthCell
            let month = parent.months[indexPath.row]
            cell.configure(month: month, parent: parent)
            return cell
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let tv = scrollView as? UITableView, currentMonthIndex >= 0 else { return }
            let visible = tv.indexPathsForVisibleRows?.map(\.row) ?? []
            let isVisible = visible.contains(currentMonthIndex)
            parent.onCurrentMonthVisibilityChanged?(isVisible)
        }
    }
}

// MARK: - Month Cell

private final class MonthCell: UITableViewCell {
    private let headerLabel = UILabel()
    private let divider = UIView()
    private let gridView = MonthGridDrawView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        divider.backgroundColor = UIColor(DesignColors.divider)
        headerLabel.textAlignment = .center
        headerLabel.textColor = UIColor(DesignColors.text)

        contentView.addSubview(divider)
        contentView.addSubview(headerLabel)
        contentView.addSubview(gridView)

        divider.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        gridView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: contentView.topAnchor),
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            headerLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerLabel.heightAnchor.constraint(equalToConstant: 20),
            gridView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            gridView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            gridView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            gridView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }()
    private static let monthYearFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    func configure(month: Date, parent: CalendarTableView) {
        let isCurrentYear = Calendar.current.component(.year, from: month) == Calendar.current.component(.year, from: Date())
        headerLabel.text = isCurrentYear ? Self.monthFmt.string(from: month) : Self.monthYearFmt.string(from: month)
        headerLabel.font = UIFont(name: "Raleway-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        gridView.configure(month: month, parent: parent)
    }
}

// MARK: - CoreGraphics Month Grid

private final class MonthGridDrawView: UIView {
    private var month = Date()
    private var periodDays: Set<String> = []
    private var predictedPeriodDays: Set<String> = []
    private var fertileDays: [String: FertilityLevel] = [:]
    private var ovulationDays: Set<String> = []
    private var selectedDate: Date?
    private var loggedDays: [String: CalendarFeature.State.DayLog] = [:]
    private var isLate = false
    private var predictedDate: Date?
    private var cycleLength = 28
    private var isEditingPeriod = false
    private var editPeriodDays: Set<String> = []
    private var onDaySelected: ((Date) -> Void)?
    private var onEditDayTapped: ((Date) -> Void)?

    private let cal = Calendar.current
    private let periodColor = UIColor(red: 0.79, green: 0.25, blue: 0.38, alpha: 1)
    private let fertileColor = UIColor(red: 0.91, green: 0.66, blue: 0.22, alpha: 1)
    private let textColor = UIColor(red: 0.36, green: 0.29, blue: 0.23, alpha: 0.55)
    private let todayColor = UIColor(red: 0.76, green: 0.56, blue: 0.49, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(month: Date, parent: CalendarTableView) {
        self.month = month
        self.periodDays = parent.periodDays
        self.predictedPeriodDays = parent.predictedPeriodDays
        self.fertileDays = parent.fertileDays
        self.ovulationDays = parent.ovulationDays
        self.selectedDate = parent.selectedDate
        self.loggedDays = parent.loggedDays
        self.isLate = parent.isLate
        self.predictedDate = parent.predictedDate
        self.cycleLength = parent.cycleLength
        self.isEditingPeriod = parent.isEditingPeriod
        self.editPeriodDays = parent.editPeriodDays
        self.onDaySelected = parent.onDaySelected
        self.onEditDayTapped = parent.onEditDayTapped
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let info = MonthGridRenderer.gridInfo(for: month)
        let cellW = bounds.width / 7
        let cellH: CGFloat = 64
        let r: CGFloat = 20
        let today = cal.startOfDay(for: Date())

        for day in 1...info.daysInMonth {
            let slot = info.offset + day - 1
            let cx = CGFloat(slot % 7) * cellW + cellW / 2
            let cy = CGFloat(slot / 7) * cellH + cellH / 2
            let key = info.keyPrefix + String(format: "%02d", day)
            guard let date = cal.date(byAdding: .day, value: day - 1, to: info.firstOfMonth) else { continue }
            let d = cal.startOfDay(for: date)

            let isConfirmed = periodDays.contains(key) && !predictedPeriodDays.contains(key)
            let isPredicted = predictedPeriodDays.contains(key)
            let isInLate: Bool = {
                guard isLate, let pred = predictedDate else { return false }
                guard let diff = cal.dateComponents([.day], from: cal.startOfDay(for: pred), to: d).day else { return false }
                return diff >= -1 && diff < cycleLength
            }()
            let isOvulation = !isInLate && ovulationDays.contains(key)
            let isFertile = !isInLate && fertileDays[key] != nil
            let isToday = d == today
            let hasLog = !(loggedDays[key]?.symptoms.isEmpty ?? true)
            let circleRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

            // Fill — hide predictions/fertile in edit mode
            if isConfirmed {
                ctx.setFillColor(periodColor.withAlphaComponent(0.75).cgColor)
                ctx.fillEllipse(in: circleRect)
            } else if !isEditingPeriod {
                if isPredicted {
                    ctx.setFillColor(periodColor.withAlphaComponent(0.18).cgColor)
                    ctx.fillEllipse(in: circleRect)
                    ctx.setStrokeColor(periodColor.withAlphaComponent(0.4).cgColor)
                    ctx.setLineWidth(0.75); ctx.setLineDash(phase: 0, lengths: [3, 3])
                    ctx.strokeEllipse(in: circleRect); ctx.setLineDash(phase: 0, lengths: [])
                } else if isOvulation {
                    ctx.setFillColor(fertileColor.withAlphaComponent(0.45).cgColor)
                    ctx.fillEllipse(in: circleRect)
                    ctx.setStrokeColor(fertileColor.withAlphaComponent(0.7).cgColor)
                    ctx.setLineWidth(1.5); ctx.strokeEllipse(in: circleRect)
                } else if isFertile {
                    ctx.setFillColor(fertileColor.withAlphaComponent(0.35).cgColor)
                    ctx.fillEllipse(in: circleRect)
                    ctx.setStrokeColor(fertileColor.withAlphaComponent(0.5).cgColor)
                    ctx.setLineWidth(1); ctx.setLineDash(phase: 0, lengths: [3, 3])
                    ctx.strokeEllipse(in: circleRect); ctx.setLineDash(phase: 0, lengths: [])
                }
            }

            if isToday {
                ctx.setStrokeColor(todayColor.cgColor)
                ctx.setLineWidth(1.5); ctx.setLineDash(phase: 0, lengths: [4, 3])
                ctx.strokeEllipse(in: circleRect); ctx.setLineDash(phase: 0, lengths: [])
            }

            // Text
            let tColor: UIColor = isConfirmed ? .white : (isToday ? todayColor : textColor)
            let font = UIFont(name: isToday || isConfirmed ? "Raleway-Bold" : "Raleway-SemiBold", size: 16) ?? .systemFont(ofSize: 16)
            let str = NSAttributedString(string: "\(day)", attributes: [.font: font, .foregroundColor: tColor])
            let sz = str.size()
            str.draw(at: CGPoint(x: cx - sz.width / 2, y: cy - sz.height / 2))

            // Edit mode: checkbox indicator
            if isEditingPeriod && d <= today {
                let isEditDay = editPeriodDays.contains(key)
                let checkY = cy + r + 9
                let checkR: CGFloat = 8
                let checkRect = CGRect(x: cx - checkR, y: checkY - checkR, width: checkR * 2, height: checkR * 2)
                if isEditDay {
                    ctx.setFillColor(periodColor.cgColor)
                    ctx.fillEllipse(in: checkRect)
                    // Checkmark
                    ctx.setStrokeColor(UIColor.white.cgColor)
                    ctx.setLineWidth(2)
                    ctx.beginPath()
                    ctx.move(to: CGPoint(x: cx - 4, y: checkY))
                    ctx.addLine(to: CGPoint(x: cx - 1, y: checkY + 3))
                    ctx.addLine(to: CGPoint(x: cx + 5, y: checkY - 3))
                    ctx.strokePath()
                } else {
                    ctx.setStrokeColor(UIColor(DesignColors.structure).withAlphaComponent(0.5).cgColor)
                    ctx.setLineWidth(1)
                    ctx.strokeEllipse(in: checkRect)
                }
            }
            // Normal mode: symptom dot / Today / Fertile label
            else if isToday {
                let label = NSAttributedString(string: "Today", attributes: [
                    .font: UIFont(name: "Raleway-Bold", size: 8) ?? .systemFont(ofSize: 8),
                    .foregroundColor: todayColor
                ])
                let ls = label.size()
                label.draw(at: CGPoint(x: cx - ls.width / 2, y: cy + r + 1))
            } else if isOvulation && !isEditingPeriod {
                let label = NSAttributedString(string: "Fertile", attributes: [
                    .font: UIFont(name: "Raleway-Bold", size: 8) ?? .systemFont(ofSize: 8),
                    .foregroundColor: fertileColor
                ])
                let ls = label.size()
                label.draw(at: CGPoint(x: cx - ls.width / 2, y: cy + r + 1))
            } else if hasLog && !isEditingPeriod {
                ctx.setFillColor(todayColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy + r + 3, width: 4, height: 4))
            }
        }
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        let loc = g.location(in: self)
        let info = MonthGridRenderer.gridInfo(for: month)
        let cellW = bounds.width / 7
        let slot = Int(loc.y / 64) * 7 + Int(loc.x / cellW)
        let day = slot - info.offset + 1
        guard day >= 1, day <= info.daysInMonth else { return }
        guard let date = cal.date(byAdding: .day, value: day - 1, to: info.firstOfMonth) else { return }
        let d = cal.startOfDay(for: date)
        guard d <= cal.startOfDay(for: Date()) else { return }
        if isEditingPeriod { onEditDayTapped?(date) } else { onDaySelected?(date) }
    }
}

// MARK: - Grid Math

enum MonthGridRenderer {
    struct GridInfo {
        let offset: Int, daysInMonth: Int, rows: Int, firstOfMonth: Date, keyPrefix: String
    }

    static func gridInfo(for month: Date) -> GridInfo {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month], from: month); c.day = 1
        let first = cal.date(from: c) ?? month
        let wd = cal.component(.weekday, from: first)
        let off = (wd + 5) % 7
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let rows = (off + days + 6) / 7
        return GridInfo(offset: off, daysInMonth: days, rows: rows, firstOfMonth: first,
                        keyPrefix: CalendarView.monthIdFormatter.string(from: month) + "-")
    }

    static func rowCount(for month: Date) -> Int { gridInfo(for: month).rows }
}
