import SwiftUI

// MARK: - Stat Metric Tile
//
// Compact mini-tile used across the Cycle Stats screen to surface a
// single statistic — average cycle length, previous cycle length,
// variation, etc. Same tonal language as `BodySignalsMetricTile`
// (warm wash + subtle border) so the screen reads as one tiled
// dashboard rather than a settings list of rows.
//
// Structure (vertical):
//   1. Eyebrow caps label  ("LAST CYCLE")
//   2. Big numeric value   ("32")
//   3. Unit caption        ("days")
//   4. Optional status     ("in range" with tinted dot)
//
// When `value` is nil/empty the tile falls back to a quiet "No data"
// state so the layout stays stable across logged / not-yet-logged
// cycles.

public struct StatMetricTile: View {
    public enum Status: Equatable, Sendable {
        /// Value sits inside a known healthy / typical window.
        /// Renders a green dot + soft "in range" caption.
        case inRange(String)
        /// Value sits outside the window — not a diagnosis, just a
        /// gentle marker so the user notices.
        case outside(String)
    }

    /// Surface treatment for the tile chrome.
    public enum Style: Sendable {
        /// Quiet warm wash + subtle border. Use when the tile is
        /// nested inside another `widgetCardStyle` parent (Normality
        /// card, Body Signals card) so the inner tile reads as a
        /// compartment without piling shadow on shadow.
        case nested
    }

    public let label: String
    public let value: String?
    public let unit: String?
    public let status: Status?
    public let style: Style
    /// When non-nil the tile becomes a Button and renders a quiet
    /// trailing chevron in the top-right corner so the user reads
    /// "drillable" at a glance instead of having to remember which
    /// tiles open an explainer sheet. `nil` for purely informational
    /// tiles (e.g. the overview averages).
    public let onTap: (() -> Void)?

    public init(
        label: String,
        value: String?,
        unit: String? = nil,
        status: Status? = nil,
        style: Style = .nested,
        onTap: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.status = status
        self.style = style
        self.onTap = onTap
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { tileContent }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Opens an explainer for \(label.lowercased())")
        } else {
            tileContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var tileContent: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            valueBlock

            statusBlock
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 110)
        .modifier(StatMetricTileChrome(style: style))
        .overlay(alignment: .bottomTrailing) {
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.55))
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Value

    @ViewBuilder
    private var valueBlock: some View {
        if let value, !value.isEmpty {
            VStack(spacing: 2) {
                Text(value)
                    .font(.raleway("Bold", size: 22, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(DesignColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.raleway("Medium", size: 11, relativeTo: .caption2))
                        .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
                        .lineLimit(1)
                }
            }
        } else {
            Text("No data")
                .font(.raleway("SemiBold", size: 13, relativeTo: .footnote))
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
                .padding(.vertical, 6)
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBlock: some View {
        if let status {
            HStack(spacing: 5) {
                Circle()
                    .fill(status.tint)
                    .frame(width: 6, height: 6)
                Text(status.copy)
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .tracking(0.4)
                    .foregroundStyle(status.textColor)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = [label]
        if let value, !value.isEmpty {
            parts.append([value, unit].compactMap { $0 }.joined(separator: " "))
        } else {
            parts.append("no data")
        }
        if let status {
            parts.append(status.copy)
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Chrome
//
// Surface treatment is split into a modifier so call sites don't
// have to know which background to apply. Currently only `.nested`
// is supported — the standalone `widgetCardStyle` variant lives in
// `StatRingTile` (different layout, ring-anchored).

private struct StatMetricTileChrome: ViewModifier {
    let style: StatMetricTile.Style

    func body(content: Content) -> some View {
        switch style {
        case .nested:
            content
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignColors.text.opacity(0.025))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(DesignColors.text.opacity(DesignColors.borderOpacitySubtle), lineWidth: 0.6)
                        }
                }
        }
    }
}

private extension StatMetricTile.Status {
    var copy: String {
        switch self {
        case .inRange(let s), .outside(let s): return s
        }
    }

    var tint: Color {
        switch self {
        case .inRange:  return DesignColors.statusSuccess
        case .outside:  return DesignColors.accentHoney
        }
    }

    var textColor: Color {
        switch self {
        case .inRange:  return DesignColors.statusSuccess
        case .outside:  return DesignColors.accentHoneyText
        }
    }
}
