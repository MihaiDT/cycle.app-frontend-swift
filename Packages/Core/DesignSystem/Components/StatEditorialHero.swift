import SwiftUI

// MARK: - Stat Editorial Hero
//
// Premium editorial display for a headline stat — eyebrow label,
// giant number, unit, single context line. A soft warm-glow halo
// sits behind the number so the hero feels embedded in the page,
// not printed on top of it.
//
// Reused across the Cycle Stats screen (Cycle length, Period length,
// Regularity, …) so each metric reads as a chapter of the same
// composition rather than a new pattern.

public struct StatEditorialHero: View {
    public let eyebrow: String
    public let value: String
    public let unit: String?
    public let context: String?

    public init(
        eyebrow: String,
        value: String,
        unit: String? = nil,
        context: String? = nil
    ) {
        self.eyebrow = eyebrow
        self.value = value
        self.unit = unit
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.8)
                .foregroundStyle(DesignColors.textSecondary)

            ZStack(alignment: .leading) {
                // Soft warm glow behind the number — anchors the hero
                // to the page without introducing a hard card edge.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignColors.accentWarm.opacity(0.22),
                                DesignColors.accentWarm.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 260, height: 260)
                    .blur(radius: 24)
                    .offset(x: -40, y: 0)
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value)
                        .font(.raleway("Bold", size: 80, relativeTo: .largeTitle))
                        .tracking(-2.0)
                        .foregroundStyle(DesignColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if let unit {
                        Text(unit)
                            .font(.raleway("Medium", size: 18, relativeTo: .body))
                            .foregroundStyle(DesignColors.textSecondary)
                            .padding(.bottom, 10)
                    }
                }
            }

            if let context, !context.isEmpty {
                Text(context)
                    .font(.raleway("Medium", size: 15, relativeTo: .body))
                    .italic()
                    .foregroundStyle(DesignColors.text.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrow). \(value) \(unit ?? ""). \(context ?? "")")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: 0xFDFCF7).ignoresSafeArea()
        StatEditorialHero(
            eyebrow: "Your rhythm",
            value: "28",
            unit: "days",
            context: "Across 6 cycles, steady and in tune."
        )
        .padding(20)
    }
}
