import SwiftUI

// MARK: - Calendar Year Legend Sheet
//
// Reference card explaining the day markers in the Year view.
// Triggered by the info button in the toolbar (Year mode only).
// Mirrors the visual treatment from `MiniMonthDrawView` so each
// legend dot reads as the same shape/colour as the actual calendar
// — no sample digits inside, the markers ARE the icon vocabulary.

struct CalendarYearLegendSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 18) {
                Text("MARKERS")
                    .font(AppTypography.cardEyebrow)
                    .tracking(AppTypography.cardEyebrowTracking)
                    .foregroundStyle(DesignColors.textSecondary)

                LegendRow(
                    marker: .solidCircle(
                        color: DesignColors.calendarPeriodGlyph,
                        opacity: 0.85
                    ),
                    title: "Period",
                    detail: "Days you've confirmed."
                )

                LegendRow(
                    marker: .dashedRing(
                        color: DesignColors.calendarPeriodGlyph,
                        opacity: 0.65
                    ),
                    title: "Predicted period",
                    detail: "Estimated for upcoming cycles."
                )

                LegendRow(
                    marker: .solidCircle(
                        color: DesignColors.calendarFertileGlyph,
                        opacity: 0.92
                    ),
                    title: "Fertile window",
                    detail: "Higher chance of conception."
                )

                LegendRow(
                    marker: .peakDisc(
                        color: DesignColors.accentWarmText,
                        opacity: 1.0
                    ),
                    title: "Ovulation",
                    detail: "Peak fertility – usually one day."
                )
            }
            .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 24)
                .padding(.vertical, 22)

            VStack(alignment: .leading, spacing: 18) {
                Text("READING")
                    .font(AppTypography.cardEyebrow)
                    .tracking(AppTypography.cardEyebrowTracking)
                    .foregroundStyle(DesignColors.textSecondary)

                LegendRow(
                    marker: .fadedDot(
                        color: DesignColors.text,
                        opacity: 0.36
                    ),
                    title: "Future days",
                    detail: "Faded so today and the past read first."
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColors.background)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How to read")
                .font(AppTypography.cardTitlePrimary)
                .tracking(AppTypography.cardTitlePrimaryTracking)
                .foregroundStyle(DesignColors.text)
            Text("What each marker means in the year view.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(DesignColors.textSecondary)
        }
    }
}

// MARK: - Legend Row

private struct LegendRow: View {
    enum Marker {
        case solidCircle(color: Color, opacity: Double)
        case dashedRing(color: Color, opacity: Double)
        case ringOnly(color: Color, opacity: Double)
        case fadedDot(color: Color, opacity: Double)
        /// Solid disc with a small ovum dot floating above —
        /// matches the ovulation marker on the Year grid.
        case peakDisc(color: Color, opacity: Double)
    }

    let marker: Marker
    let title: String
    let detail: String

    private let dotSize: CGFloat = 18

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            markerView
                .frame(width: 24, alignment: .center)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 6 }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.cardLabel)
                    .foregroundStyle(DesignColors.text)
                Text(detail)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var markerView: some View {
        switch marker {
        case .solidCircle(let color, let opacity):
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: dotSize, height: dotSize)
        case .dashedRing(let color, let opacity):
            Circle()
                .strokeBorder(
                    color.opacity(opacity),
                    style: StrokeStyle(lineWidth: 2, dash: [2.5, 1.5])
                )
                .frame(width: dotSize, height: dotSize)
        case .ringOnly(let color, let opacity):
            Circle()
                .strokeBorder(color.opacity(opacity), lineWidth: 2)
                .frame(width: dotSize, height: dotSize)
        case .fadedDot(let color, let opacity):
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: dotSize - 4, height: dotSize - 4)
        case .peakDisc(let color, let opacity):
            VStack(spacing: 2) {
                Circle()
                    .fill(color.opacity(opacity))
                    .frame(width: 4, height: 4)
                Circle()
                    .fill(color.opacity(opacity))
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarYearLegendSheet()
}
