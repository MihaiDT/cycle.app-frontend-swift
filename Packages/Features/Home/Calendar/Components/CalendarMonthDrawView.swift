import SwiftUI
import UIKit

// MARK: - CoreGraphics Month Grid

final class MonthGridDrawView: UIView {
    var month = Date()
    var periodDays: Set<String> = []
    var predictedPeriodDays: Set<String> = []
    var fertileDays: [String: FertilityLevel] = [:]
    var ovulationDays: Set<String> = []
    var selectedDate: Date?
    var loggedDays: [String: CalendarFeature.State.DayLog] = [:]
    var isLate = false
    var predictedDate: Date?
    var cycleLength = 28
    var cycleStartDate: Date = Date()
    var bleedingDays: Int = 5
    var isEditingPeriod = false
    var editPeriodDays: Set<String> = []
    var onDaySelected: ((Date) -> Void)?
    var onEditDayTapped: ((Date) -> Void)?
    /// Cycle ranges derived from logged + predicted period starts. Each range
    /// extends from one cycle anchor up to the next anchor (or anchor + cycleLength
    /// if no next anchor). The first range also extends backward by one cycleLength
    /// so the prior cycle's luteal end stays coloured. Together the ranges cover
    /// every day inside the user's logged horizon with zero gaps.
    var cycleRanges: [(start: Date, end: Date)] = []

    let cal = Calendar.current
    /// Padding between the day-label grid and the screen edge. Matches the
    /// 8pt padding applied to `WeekdayLabelsRow` in CalendarView so the
    /// labels stay aligned. Pills that continue across week breaks bleed
    /// past this inset all the way to the screen edge.
    let horizontalInset: CGFloat = 8
    let periodColor = UIColor(DesignColors.calendarPeriodGlyph)
    let textColor = UIColor(DesignColors.calendarDayText).withAlphaComponent(0.55)
    let todayColor = UIColor(DesignColors.calendarTodayRing)
    let follicularColor = UIColor(DesignColors.calendarFollicularGlyph)
    let ovulatoryColor = UIColor(DesignColors.calendarFertileGlyph)
    let lutealColor = UIColor(DesignColors.calendarLutealGlyph)
    let lateColor = UIColor(DesignColors.textPlaceholder)

    /// Renders a single phase pill: solid fill for most styles, horizontal gradient for ovulatory
    /// peaked on the ovulation day so saturation rises into ovulation and fades out either side.
    /// `continuesLeft`/`continuesRight` strip the rounded caps on the side where the same phase
    /// continues into the previous/next week so the run reads as one capsule split by week breaks.
    private func drawPill(_ ctx: CGContext, rect: CGRect, style: PillStyle, peakX: CGFloat?, continuesLeft: Bool, continuesRight: Bool) {
        let radius = rect.height / 2
        var corners: UIRectCorner = []
        if !continuesLeft { corners.insert(.topLeft); corners.insert(.bottomLeft) }
        if !continuesRight { corners.insert(.topRight); corners.insert(.bottomRight) }
        let path: CGPath = corners.isEmpty
            ? CGPath(rect: rect, transform: nil)
            : UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath

        // Late period — dashed grey outline only, no fill or clipping. The capsule
        // is drawn as a stroke so it reads as a tentative "expected period not yet
        // confirmed" without competing visually with logged or predicted period rose.
        if style == .latePeriod {
            ctx.saveGState()
            ctx.setStrokeColor(lateColor.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: 0, lengths: [4, 3])
            ctx.addPath(path)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
            ctx.restoreGState()
            return
        }

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        switch style {
        case .confirmedPeriod:
            ctx.setFillColor(periodColor.withAlphaComponent(0.75).cgColor)
            ctx.fill(rect)
        case .predictedPeriod:
            // Solid rose fill — identical to confirmed period treatment. Predicted
            // period only renders for today/future days (gated in pillStyle), and
            // Pass 3's future-fade overlay desaturates it so the visual still
            // reads "tentative" without needing a stripe pattern.
            ctx.setFillColor(periodColor.withAlphaComponent(0.75).cgColor)
            ctx.fill(rect)
        case .latePeriod:
            // Handled by early-return above; this case exists only to satisfy
            // exhaustive switch checking.
            break
        case .follicular:
            ctx.setFillColor(follicularColor.withAlphaComponent(0.70).cgColor)
            ctx.fill(rect)
        case .luteal:
            ctx.setFillColor(lutealColor.withAlphaComponent(0.55).cgColor)
            ctx.fill(rect)
        case .ovulatory:
            // Fertile-window pill — peach throughout. Only the row that contains the
            // ovulation day gets a saturation peak (same hue, just deeper alpha) so the
            // gradient reads as one warm crescendo without introducing a second color
            // family that would compete with period rose.
            if let px = peakX, rect.width > 0 {
                let cs = CGColorSpaceCreateDeviceRGB()
                let edge = ovulatoryColor.withAlphaComponent(0.32).cgColor
                let peak = ovulatoryColor.withAlphaComponent(0.75).cgColor
                let peakLoc = max(0.0, min(1.0, (px - rect.minX) / rect.width))
                let colors: [CGColor] = [edge, peak, edge]
                let locations: [CGFloat] = [0.0, peakLoc, 1.0]
                if let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locations) {
                    ctx.drawLinearGradient(
                        g,
                        start: CGPoint(x: rect.minX, y: rect.midY),
                        end: CGPoint(x: rect.maxX, y: rect.midY),
                        options: []
                    )
                }
            } else {
                // No peak in this segment (ovulation day is in another row of the
                // same fertile window) — keep alpha close to the gradient edge so
                // the visual feel of the peach band stays consistent across rows.
                ctx.setFillColor(ovulatoryColor.withAlphaComponent(0.42).cgColor)
                ctx.fill(rect)
            }
        }

        ctx.restoreGState()
    }

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
        self.cycleStartDate = parent.cycleStartDate
        self.bleedingDays = parent.bleedingDays
        self.isEditingPeriod = parent.isEditingPeriod
        self.editPeriodDays = parent.editPeriodDays
        self.onDaySelected = parent.onDaySelected
        self.onEditDayTapped = parent.onEditDayTapped
        // Compute cycle anchors: first day of each multi-day run of logged or
        // predicted period days. Single-day isolated entries are skipped (server
        // quirks). Then build ranges that fill every gap between adjacent cycles
        // — each range extends to max(next anchor, anchor + cycleLength), and the
        // first range also extends one cycleLength backward to colour the prior
        // cycle's luteal end. Result: zero gaps inside the logged horizon.
        let allPeriodKeys = parent.periodDays.union(parent.predictedPeriodDays)
        let anchors: [Date] = allPeriodKeys.compactMap { key -> Date? in
            guard let date = CalendarFeature.parseDate(key) else { return nil }
            guard let next = cal.date(byAdding: .day, value: 1, to: date),
                  allPeriodKeys.contains(CalendarFeature.dateKey(next)) else { return nil }
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { return date }
            return allPeriodKeys.contains(CalendarFeature.dateKey(prev)) ? nil : date
        }.sorted()

        let cl = parent.cycleLength
        self.cycleRanges = anchors.enumerated().map { idx, anchor in
            let cycleEnd = cal.date(byAdding: .day, value: cl, to: anchor) ?? anchor
            let rangeEnd: Date
            if idx + 1 < anchors.count {
                rangeEnd = max(anchors[idx + 1], cycleEnd)
            } else {
                // Last anchor: project two cycles forward so the next predicted
                // cycle (and its phase pills) renders even when the predictor
                // hasn't supplied a hard `predicted_period` anchor yet.
                rangeEnd = cal.date(byAdding: .day, value: cl * 2, to: anchor) ?? cycleEnd
            }
            // No backward extension — phase pills only render forward from a real
            // anchor. Pre-first-anchor months stay empty (the user hasn't logged
            // those cycles, so we don't fabricate past phase pills there).
            return (anchor, rangeEnd)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let info = MonthGridRenderer.gridInfo(for: month)
        // Day-label grid lives inside `horizontalInset`; pills can spill into the
        // outer margin when they continue across a week break.
        let cellW = (bounds.width - horizontalInset * 2) / 7
        let cellH: CGFloat = 56
        let pillH: CGFloat = 38
        let pillVPad = (cellH - pillH) / 2
        let today = cal.startOfDay(for: Date())

        // Build segments per row, then mark continuesLeft/continuesRight so a phase that
        // spans week breaks reads as one capsule (square caps at the break, rounded at the
        // true ends). Without this each week starts a fresh rounded pill, which fragments
        // the eye-line across the fertile window or any long phase.
        var allRows: [[PillSegment]] = (0..<info.rows).map { pillSegments(forRow: $0, info: info, cellW: cellW) }
        for r in 0..<allRows.count {
            for s in 0..<allRows[r].count {
                var seg = allRows[r][s]
                if seg.endCol == 6, r + 1 < allRows.count,
                   let next = allRows[r + 1].first,
                   next.startCol == 0, next.style == seg.style {
                    seg.continuesRight = true
                }
                if seg.startCol == 0, r > 0,
                   let prev = allRows[r - 1].last,
                   prev.endCol == 6, prev.style == seg.style {
                    seg.continuesLeft = true
                }
                allRows[r][s] = seg
            }
        }

        // Pass 1: Phase pills (continuous capsules per phase run, per row).
        // In edit mode we keep only confirmed-period pills so the editor stays focused.
        // Segments that continue into the previous/next week bleed into the outer
        // horizontal inset, so the eye reads the run as one capsule cut by the week edge.
        for row in 0..<allRows.count {
            for seg in allRows[row] {
                if isEditingPeriod && seg.style != .confirmedPeriod { continue }
                let leftMargin: CGFloat = seg.continuesLeft ? 0 : 1
                let rightMargin: CGFloat = seg.continuesRight ? 0 : 1
                let xStart: CGFloat = seg.continuesLeft
                    ? 0
                    : horizontalInset + CGFloat(seg.startCol) * cellW + leftMargin
                let xEnd: CGFloat = seg.continuesRight
                    ? bounds.width
                    : horizontalInset + CGFloat(seg.endCol + 1) * cellW - rightMargin
                let y = CGFloat(row) * cellH + pillVPad
                let pillRect = CGRect(x: xStart, y: y, width: xEnd - xStart, height: pillH)
                drawPill(
                    ctx,
                    rect: pillRect,
                    style: seg.style,
                    peakX: seg.peakAbsX,
                    continuesLeft: seg.continuesLeft,
                    continuesRight: seg.continuesRight
                )
            }
        }

        // Pass 2: Day labels and per-day indicators (today ring, log dot, edit checkbox).
        for day in 1...info.daysInMonth {
            let slot = info.offset + day - 1
            let cx = horizontalInset + CGFloat(slot % 7) * cellW + cellW / 2
            let cy = CGFloat(slot / 7) * cellH + cellH / 2
            let key = info.keyPrefix + String(format: "%02d", day)
            guard let date = cal.date(byAdding: .day, value: day - 1, to: info.firstOfMonth) else { continue }
            let d = cal.startOfDay(for: date)

            let isConfirmed = periodDays.contains(key)
            let isPredictedRun = predictedPeriodDays.contains(key)
                && hasNeighborIn(predictedPeriodDays, around: date)
                && !hasLoggedPeriodNear(date: date)
                && d >= today
            let isPeriodPill = isConfirmed || isPredictedRun
            let isToday = d == today
            let hasLog = !(loggedDays[key]?.symptoms.isEmpty ?? true)
            let isOvulation = ovulationDays.contains(key)

            // Today: subtle dashed ring sitting on top of any pill — kept inset from
            // the pill edges (38pt → 32pt) so it reads as a focus ring, not a border.
            if isToday {
                let ringRect = CGRect(x: cx - 16, y: cy - 16, width: 32, height: 32)
                ctx.setStrokeColor(todayColor.cgColor)
                ctx.setLineWidth(1.5)
                ctx.setLineDash(phase: 0, lengths: [4, 3])
                ctx.strokeEllipse(in: ringRect)
                ctx.setLineDash(phase: 0, lengths: [])
            }

            // Day number
            // Future days get a faded number/label only — the pill colour stays
            // full saturation so the phase palette reads consistently across
            // past/today/future. The fade signals "predicted, not yet here".
            let isFuture = d > today
            let baseTColor: UIColor = isPeriodPill ? .white : (isToday ? todayColor : textColor)
            let tColor: UIColor = isFuture ? baseTColor.withAlphaComponent(0.35) : baseTColor
            let font = UIFont.raleway(isToday || isPeriodPill ? "Bold" : "SemiBold", size: 18, textStyle: .body)
            let str = NSAttributedString(string: "\(day)", attributes: [.font: font, .foregroundColor: tColor])
            let sz = str.size()
            str.draw(at: CGPoint(x: cx - sz.width / 2, y: cy - sz.height / 2))

            // Edit mode: checkbox indicator (limited to today + 7d window)
            let editCutoff = cal.date(byAdding: .day, value: 7, to: today) ?? today
            if isEditingPeriod && d <= editCutoff {
                let isEditDay = editPeriodDays.contains(key)
                let checkY = cy + 19 + 9
                let checkR: CGFloat = 8
                let checkRect = CGRect(x: cx - checkR, y: checkY - checkR, width: checkR * 2, height: checkR * 2)
                if isEditDay {
                    ctx.setFillColor(periodColor.cgColor)
                    ctx.fillEllipse(in: checkRect)
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
            // Normal mode indicators: Today label / Fertile label / log dot
            else if isToday {
                let label = NSAttributedString(string: "Today", attributes: [
                    .font: UIFont.raleway("Bold", size: 8, textStyle: .caption2),
                    .foregroundColor: todayColor
                ])
                let ls = label.size()
                label.draw(at: CGPoint(x: cx - ls.width / 2, y: cy + 19 + 1))
            } else if isOvulation {
                let label = NSAttributedString(string: "Fertile", attributes: [
                    .font: UIFont.raleway("Bold", size: 8, textStyle: .caption2),
                    .foregroundColor: ovulatoryColor
                ])
                let ls = label.size()
                label.draw(at: CGPoint(x: cx - ls.width / 2, y: cy + 19 + 1))
            } else if hasLog {
                ctx.setFillColor(todayColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy + 19 + 3, width: 4, height: 4))
            }
        }

    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        let loc = g.location(in: self)
        let info = MonthGridRenderer.gridInfo(for: month)
        let cellW = (bounds.width - horizontalInset * 2) / 7
        let xInGrid = loc.x - horizontalInset
        guard xInGrid >= 0, xInGrid <= cellW * 7 else { return }
        let slot = Int(loc.y / 56) * 7 + Int(xInGrid / cellW)
        let day = slot - info.offset + 1
        guard day >= 1, day <= info.daysInMonth else { return }
        guard let date = cal.date(byAdding: .day, value: day - 1, to: info.firstOfMonth) else { return }
        let d = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        if isEditingPeriod {
            // Allow tapping up to 7 days in future for edit mode
            let cutoff = cal.date(byAdding: .day, value: 7, to: today) ?? today
            guard d <= cutoff else { return }
            onEditDayTapped?(date)
        } else {
            guard d <= today else { return }
            onDaySelected?(date)
        }
    }
}
