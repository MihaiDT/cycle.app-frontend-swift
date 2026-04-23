import SwiftUI

// MARK: - Echo Card
//
// Compact card that surfaces a "one cycle ago today" echo on Home's
// Journey page. Previews the matching day from the previous cycle —
// phrase, mini mood/energy dots, date. Tapping it opens the full
// `DayDetailView` sheet with every signal logged for that date.

public struct EchoCard: View {
    public let payload: DayDetailPayload
    public let onTap: (() -> Void)?

    public init(payload: DayDetailPayload, onTap: (() -> Void)? = nil) {
        self.payload = payload
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            cardContent
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(background)
                .overlay(border)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            phraseLine
            signalRow
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("ECHO · ONE CYCLE AGO")
                .font(.raleway("SemiBold", size: 10, relativeTo: .caption2))
                .tracking(1.5)
                .foregroundStyle(DesignColors.textSecondary)
            Spacer()
            Text(dateLabel)
                .font(.raleway("Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
    }

    @ViewBuilder
    private var phraseLine: some View {
        Text("\u{201C}\(payload.phrase).\u{201D}")
            .font(.raleway("Bold", size: 17, relativeTo: .headline))
            .italic()
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var signalRow: some View {
        HStack(spacing: 10) {
            if payload.hasAnyData {
                if let mood = payload.mood {
                    signalChip(label: "MOOD", value: mood)
                }
                if let energy = payload.energy {
                    signalChip(label: "ENERGY", value: energy)
                }
                if payload.moment != nil {
                    momentChip
                }
            } else {
                Text("this day wasn't tracked")
                    .font(.raleway("Medium", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
        }
    }

    @ViewBuilder
    private func signalChip(label: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.raleway("SemiBold", size: 8, relativeTo: .caption2))
                .tracking(0.8)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.75))
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < value ? DesignColors.accentWarm : DesignColors.text.opacity(0.1))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }

    @ViewBuilder
    private var momentChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DesignColors.accentWarm)
            Text("MOMENT")
                .font(.raleway("SemiBold", size: 8, relativeTo: .caption2))
                .tracking(0.8)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
    }

    // MARK: - Style

    @ViewBuilder
    private var background: some View {
        LinearGradient(
            colors: [Color(hex: 0xFDFCF7), Color(hex: 0xF3E5D4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var border: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(DesignColors.text.opacity(0.08), lineWidth: 1)
    }

    // MARK: - Formatting

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: payload.date).uppercased()
            + " · DAY \(payload.cycleDay)"
    }

    private var a11yLabel: String {
        "Echo from one cycle ago. \(dateLabel). \(payload.phrase). Tap to see full day."
    }
}
