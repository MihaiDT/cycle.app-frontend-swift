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
    let cycleStartDate: Date
    let bleedingDays: Int
    let showOvulation: Bool
    let showFertileWindow: Bool
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
        tv.backgroundColor = .clear
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
            // Crossfade reload on edit toggle
            UIView.transition(with: tv, duration: 0.25, options: .transitionCrossDissolve) {
                tv.reloadData()
            }
        } else if old.periodDays != periodDays || old.predictedPeriodDays != predictedPeriodDays
            || old.editPeriodDays != editPeriodDays
            || old.fertileDays != fertileDays || old.selectedDate != selectedDate
            || old.showOvulation != showOvulation || old.showFertileWindow != showFertileWindow {
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
            // header(36) + grid(rows * 56) + bottom padding(28)
            return 36 + CGFloat(rows) * 56 + 28
        }

        func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tv.dequeueReusableCell(withIdentifier: "m", for: indexPath) as! MonthCell
            let month = parent.months[indexPath.row]
            cell.configure(month: month, parent: parent)
            return cell
        }

        /// Cached last reported visibility so we only fire the binding
        /// write when the value actually flips. `scrollViewDidScroll`
        /// runs on every frame during scroll (60-120Hz); without this
        /// guard, each frame propagated a @State write up to CalendarView
        /// even when `isVisible` was unchanged, which meant every scroll
        /// tick invalidated CalendarView's body + all its descendants.
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let tv = scrollView as? UITableView, currentMonthIndex >= 0 else { return }
            let visible = tv.indexPathsForVisibleRows?.map(\.row) ?? []
            let isVisible = visible.contains(currentMonthIndex)
            if isVisible != lastReportedVisibility {
                lastReportedVisibility = isVisible
                parent.onCurrentMonthVisibilityChanged?(isVisible)
            }
        }

        private var lastReportedVisibility: Bool?
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
            // gridView spans the full content width — pills that continue across week
            // breaks use this extra margin to bleed past the day-label grid into the
            // screen edge. Internal padding (matching the SwiftUI WeekdayLabelsRow) is
            // applied inside MonthGridDrawView via `horizontalInset`.
            gridView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            gridView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            gridView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(month: Date, parent: CalendarTableView) {
        let isCurrentYear = Calendar.current.component(.year, from: month) == Calendar.current.component(.year, from: Date())
        headerLabel.text = isCurrentYear ? DateFormatter.monthName.string(from: month) : DateFormatter.monthYear.string(from: month)
        headerLabel.font = UIFont.raleway("Bold", size: 16, textStyle: .headline)
        gridView.configure(month: month, parent: parent)
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
