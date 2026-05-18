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
    var showOvulation: Bool = true
    var showFertileWindow: Bool = true
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
    /// Warm rose tied back to the period palette — late-period dashed pills now
    /// read as "tentative period" instead of "missing data" against the new warm
    /// tonal wheel. Previously used a cold `textPlaceholder` grey that sat off-palette.
    let lateColor = UIColor(DesignColors.calendarPeriodGlyph)

    /// Renders a single phase pill: solid fill for most styles, horizontal gradient for ovulatory
    /// peaked on the ovulation day so saturation rises into ovulation and fades out either side.
    /// `continuesLeft`/`continuesRight` strip the rounded caps on the side where the same phase
    /// continues into the previous/next week so the run reads as one capsule split by week breaks.
    /// `futureStartX` is the absolute x of the first future day's left edge inside this segment;
    /// the portion of the pill from that x onward gets a soft white future-fade overlay so
    /// predicted days read as tentative without losing pill identity. Nil = no future portion.
    /// `futureFadeSmooth` toggles a smooth gradient transition into the wash (used when the
    /// past→future boundary sits inside this row) vs a uniform wash (segment is fully future,
    /// no in-row boundary to smooth). The smooth variant kills the visible seam that would
    /// otherwise sit at today's right edge.
    private func drawPill(_ ctx: CGContext, rect: CGRect, style: PillStyle, peakX: CGFloat?, continuesLeft: Bool, continuesRight: Bool, futureStartX: CGFloat?, futureFadeSmooth: Bool) {
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
            ctx.setStrokeColor(lateColor.withAlphaComponent(0.45).cgColor)
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
            ctx.setFillColor(follicularColor.withAlphaComponent(0.78).cgColor)
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
                // same fertile window) — match the standard phase-pill alpha so the
                // fertile band still reads distinctly from adjacent luteal mauve
                // instead of fading into it at the row break.
                ctx.setFillColor(ovulatoryColor.withAlphaComponent(0.55).cgColor)
                ctx.fill(rect)
            }
        }

        // Future-fade overlay — soft white wash on the portion of the pill that
        // sits past `today`. Clipped to the pill path so rounded caps survive.
        // 0.30 desaturates predicted days enough to register as tentative without
        // erasing the phase identity. When the past→future boundary lives inside
        // this row (`futureFadeSmooth`), the wash fades in over ~one cell width so
        // there's no visible vertical seam at today's right edge. Fully-future
        // segments use a uniform wash (the row break already breaks visual continuity).
        if let fx = futureStartX, fx < rect.maxX {
            let clamped = max(rect.minX, fx)
            let washRect = CGRect(x: clamped, y: rect.minY, width: rect.maxX - clamped, height: rect.height)
            let washColor = UIColor.white.withAlphaComponent(0.30).cgColor
            if futureFadeSmooth && washRect.width > 1 {
                let cs = CGColorSpaceCreateDeviceRGB()
                let clearColor = UIColor.white.withAlphaComponent(0.0).cgColor
                let transitionWidth: CGFloat = 44
                let transitionEnd = min(1.0, transitionWidth / washRect.width)
                let colors: [CGColor] = [clearColor, washColor, washColor]
                let locations: [CGFloat] = [0.0, transitionEnd, 1.0]
                if let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locations) {
                    ctx.drawLinearGradient(
                        g,
                        start: CGPoint(x: washRect.minX, y: washRect.midY),
                        end: CGPoint(x: washRect.maxX, y: washRect.midY),
                        options: []
                    )
                }
            } else {
                ctx.setFillColor(washColor)
                ctx.fill(washRect)
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
        self.showOvulation = parent.showOvulation
        self.showFertileWindow = parent.showFertileWindow
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
        // When the user has pinned bleedingDays to 1, every predicted
        // day is by definition an isolated single-day entry — the
        // standard "needs a consecutive neighbor" check would drop all
        // future cycle anchors and the phase pills would never project
        // past the first one.
        let allowSingleDayAnchors = parent.bleedingDays <= 1
        let anchors: [Date] = allPeriodKeys.compactMap { key -> Date? in
            guard let date = CalendarFeature.parseDate(key) else { return nil }
            let nextKey = cal.date(byAdding: .day, value: 1, to: date).map(CalendarFeature.dateKey)
            let prevKey = cal.date(byAdding: .day, value: -1, to: date).map(CalendarFeature.dateKey)
            let hasNext = nextKey.map(allPeriodKeys.contains) ?? false
            let hasPrev = prevKey.map(allPeriodKeys.contains) ?? false
            if !hasNext && !allowSingleDayAnchors { return nil }
            return hasPrev ? nil : date
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
                // First future day's left-edge x inside this segment, if any. drawPill
                // uses it to paint a soft white wash on the future portion so predicted
                // periods (and any phase extending past today) read as tentative. When
                // the past→future boundary lives mid-segment (today is somewhere inside
                // this row), `futureFadeSmooth` triggers a gradient fade-in so there's
                // no visible vertical seam at today's right edge. Segments that are
                // already-future from their first column use a uniform wash — the row
                // break before them already provides the natural visual transition.
                var futureStartX: CGFloat? = nil
                var futureFadeSmooth = false
                for c in seg.startCol...seg.endCol {
                    let slot = row * 7 + c
                    let dayN = slot - info.offset + 1
                    guard dayN >= 1, dayN <= info.daysInMonth,
                          let dt = cal.date(byAdding: .day, value: dayN - 1, to: info.firstOfMonth) else { continue }
                    if cal.startOfDay(for: dt) > today {
                        if c == seg.startCol {
                            futureStartX = seg.continuesLeft
                                ? 0
                                : horizontalInset + CGFloat(c) * cellW
                            futureFadeSmooth = false
                        } else {
                            futureStartX = horizontalInset + CGFloat(c) * cellW
                            futureFadeSmooth = true
                        }
                        break
                    }
                }
                drawPill(
                    ctx,
                    rect: pillRect,
                    style: seg.style,
                    peakX: seg.peakAbsX,
                    continuesLeft: seg.continuesLeft,
                    continuesRight: seg.continuesRight,
                    futureStartX: futureStartX,
                    futureFadeSmooth: futureFadeSmooth
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
            // The neighbor check drops accidental single-day entries
            // (data quirks). It also drops legitimate 1-day period
            // predictions — skip it when the user has explicitly
            // pinned bleedingDays to 1.
            let needsNeighborCheck = bleedingDays > 1
            let isPredictedRun = predictedPeriodDays.contains(key)
                && (!needsNeighborCheck || hasNeighborIn(predictedPeriodDays, around: date))
                && !hasLoggedPeriodNear(date: date)
                && d >= today
            let isPeriodPill = isConfirmed || isPredictedRun
            let isToday = d == today
            let hasLog = !(loggedDays[key]?.symptoms.isEmpty ?? true)
            let isOvulation = ovulationDays.contains(key)
            // A day sits on a fertile gradient when it's the ovulation peak or any
            // day in the 6-day fertile window. The gradient peak alpha is high enough
            // (0.75 peach) that the muted day-text and the rose todayColor (which is
            // the *same hue* as calendarFertileGlyph) both vanish into the background.
            // Detect it here so we can swap to a high-contrast deep brown below.
            let isOnFertilePill = ovulationDays.contains(key) || fertileDays[key] != nil

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
            // Future-tentativeness is communicated by the pill's own future-fade wash
            // (Pass 1 inside drawPill). Text stays at full alpha so numbers remain
            // legible on the washed pill background; layering a second text-alpha fade
            // on top dropped contrast below AA on the lighter phase pills.
            // Fertile pill needs the deep day-text colour at full opacity. The
            // standard textColor (×0.55) and todayColor both share hue with the
            // peach gradient and dissolve into it.
            let fertileTextColor = UIColor(DesignColors.calendarDayText)
            let tColor: UIColor
            if isPeriodPill {
                tColor = .white
            } else if isOnFertilePill {
                tColor = fertileTextColor
            } else if isToday {
                tColor = todayColor
            } else {
                tColor = textColor
            }
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
