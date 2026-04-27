import SwiftUI

// MARK: - Chart Card Wrapper
//
// Apple Health-style metric card used by every section in the Your
// Body detail screen. Hierarchy:
//
//   1. Header row: small outline icon + caps title
//   2. Big primary value with unit ("26 ms") — Apple Health treats
//      this as the hero. When there's no reading yet the value
//      collapses to a quiet "No Data" string at the same scale.
//   3. Delta caption underneath ("−17 vs menstrual avg" /
//      "+1 from baseline") — colored subtly so positive vs negative
//      reads at a glance without shouting.
//   4. Chart content (whatever the section provides).
//   5. Footnote — the "what does this mean" copy.
//
// Generic over the chart so wrist temp / HRV / RHR can plug in their
// own marks without re-declaring the frame.

struct BodySignalsChartCard<Chart: View>: View {
    let title: String
    let iconName: String
    /// Primary numeric reading with unit, e.g. "26 ms". `nil` →
    /// "No Data" rendering at the same display weight.
    let value: String?
    /// Secondary delta caption, e.g. "−17 vs menstrual avg". `nil`
    /// when we don't have enough data to compute one yet.
    let delta: String?
    let footnote: String
    /// Plain-language explanation of what the metric measures and
    /// what unit the chart uses. When non-nil, an `info.circle`
    /// button appears next to the title; tap opens a system alert
    /// with this copy. Useful for demystifying units like "ms" or
    /// "bpm" without bloating the card surface.
    let infoCopy: String?
    @ViewBuilder let chart: () -> Chart

    @State private var showingInfo = false

    init(
        title: String,
        iconName: String,
        value: String?,
        delta: String?,
        footnote: String,
        infoCopy: String? = nil,
        @ViewBuilder chart: @escaping () -> Chart
    ) {
        self.title = title
        self.iconName = iconName
        self.value = value
        self.delta = delta
        self.footnote = footnote
        self.infoCopy = infoCopy
        self.chart = chart
    }

    var body: some View {
        Button {
            if infoCopy != nil { showingInfo = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                // Oversized SF Symbol painted at very low opacity in
                // the top-right corner of every card. Carries the
                // metric's identity across card → info sheet without
                // competing with the headline data.
                Image(systemName: iconName)
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundStyle(DesignColors.text.opacity(0.05))
                    .offset(x: 22, y: -16)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    headerBlock
                    chart()
                    Text(footnote)
                        .font(.raleway("Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .widgetCardStyle(cornerRadius: 24, rasterize: false, interactive: true)
        .disabled(infoCopy == nil)
        .sheet(isPresented: $showingInfo) {
            BodySignalInfoSheet(
                title: title,
                copy: infoCopy ?? "",
                iconName: iconName
            )
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.regularMaterial)
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColors.textSecondary)
                Text(title.uppercased())
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)

                Spacer(minLength: 0)
            }

            valueBlock
        }
    }

    @ViewBuilder
    private var valueBlock: some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                    .tracking(-0.6)
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let delta, !delta.isEmpty {
                    Text(delta)
                        .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
        } else {
            Text("No Data")
                .font(.raleway("Bold", size: 30, relativeTo: .largeTitle))
                .tracking(-0.6)
                .foregroundStyle(DesignColors.text.opacity(0.85))
        }
    }
}

// MARK: - Info Sheet
//
// Lightweight explainer surface presented from `info.circle` taps in
// the chart card title row. Sheet (not alert) so the copy reads as
// "here's some context", not "something went wrong" — alerts in iOS
// carry an error/decision tone the explanatory text shouldn't borrow.

private struct BodySignalInfoSheet: View {
    let title: String
    let copy: String
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.raleway("Bold", size: 22, relativeTo: .title2))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)

            Text(copy)
                .font(.raleway("Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            // Oversized SF Symbol painted at very low opacity in the
            // top-right corner — reads as watermark texture, not as
            // an interactive control. Pushed slightly past the sheet
            // edge so it feels like a backdrop motif rather than a
            // measured icon. Ignored by accessibility.
            Image(systemName: iconName)
                .font(.system(size: 100, weight: .ultraLight))
                .foregroundStyle(DesignColors.text.opacity(0.08))
                .offset(x: 24, y: -18)
                .accessibilityHidden(true)
        }
        .clipped()
    }
}
