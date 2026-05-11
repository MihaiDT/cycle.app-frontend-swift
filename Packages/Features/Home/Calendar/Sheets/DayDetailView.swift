import SwiftUI

// MARK: - Day Detail View
//
// Full-screen snapshot of a single past day, presented as a sheet when
// the user taps an Echo card (or a key day inside a recap). Lays out
// every signal we have for that day — check-in levels, moment details,
// HBI — plus a footer link that jumps into the full cycle recap.

struct DayDetailView: View {
    let payload: DayDetailPayload
    let onDismiss: () -> Void
    let onOpenRecap: (() -> Void)?

    init(
        payload: DayDetailPayload,
        onDismiss: @escaping () -> Void,
        onOpenRecap: (() -> Void)? = nil
    ) {
        self.payload = payload
        self.onDismiss = onDismiss
        self.onOpenRecap = onOpenRecap
    }

    var body: some View {
        ZStack {
            AppleHealthBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    heroPhrase
                        .padding(.horizontal, 22)
                        .padding(.bottom, 28)

                    checkInSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)

                    momentSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)

                    wellnessSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 28)

                    if onOpenRecap != nil {
                        recapLink
                            .padding(.horizontal, 22)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            AppCloseButton(action: onDismiss)
            Spacer()
        }
        .overlay(alignment: .center) {
            VStack(spacing: 2) {
                Text(dateHeading)
                    .font(AppTypography.modalHeader)
                    .foregroundStyle(DesignColors.text)
                Text("CYCLE \(payload.cycleNumber) · DAY \(payload.cycleDay) · \(payload.phase.displayName.uppercased())")
                    .font(AppTypography.cardEyebrow)
                    .tracking(AppTypography.cardEyebrowTracking)
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    // MARK: Hero phrase

    @ViewBuilder
    private var heroPhrase: some View {
        Text("\u{201C}\(payload.phrase).\u{201D}")
            .font(AppTypography.heroDisplay)
            .tracking(AppTypography.heroDisplayTracking)
            .foregroundStyle(DesignColors.text)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Check-in

    @ViewBuilder
    private var checkInSection: some View {
        sectionCard(title: "HOW YOU FELT") {
            if hasAnyCheckIn {
                VStack(spacing: 12) {
                    levelRow(label: "Mood", value: payload.mood)
                    levelRow(label: "Energy", value: payload.energy)
                    levelRow(label: "Stress", value: payload.stress)
                    levelRow(label: "Sleep", value: payload.sleep)
                }
            } else {
                Text("No check-in logged this day.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    private var hasAnyCheckIn: Bool {
        payload.mood != nil
            || payload.energy != nil
            || payload.stress != nil
            || payload.sleep != nil
    }

    @ViewBuilder
    private func levelRow(label: String, value: Int?) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(AppTypography.cardLabel)
                .foregroundStyle(DesignColors.text)

            Spacer()

            if let value {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < value ? DesignColors.accentWarm : DesignColors.text.opacity(0.1))
                            .frame(width: 8, height: 8)
                    }
                }
                Text("\(value) of 5")
                    .font(.raleway("Medium", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
                    .monospacedDigit()
            } else {
                Text("–")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
            }
        }
    }

    // MARK: Moment

    @ViewBuilder
    private var momentSection: some View {
        sectionCard(title: "YOUR MOMENT") {
            if let moment = payload.moment {
                HStack(alignment: .top, spacing: 14) {
                    momentThumbnail(moment: moment)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(moment.title)
                            .font(AppTypography.modalHeader)
                            .foregroundStyle(DesignColors.text)
                            .lineLimit(2)
                        Text(categoryLabel(moment.category))
                            .font(.raleway("SemiBold", size: 11, relativeTo: .caption))
                            .foregroundStyle(DesignColors.accentWarmText)
                        if let feedback = moment.validationFeedback, !feedback.isEmpty {
                            Text("\u{201C}\(feedback)\u{201D}")
                                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                                .italic()
                                .foregroundStyle(DesignColors.textSecondary)
                                .lineLimit(3)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("No moment logged this day.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func momentThumbnail(moment: DayDetailPayload.Moment) -> some View {
        if let data = moment.photoThumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignColors.accentWarm.opacity(0.12))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DesignColors.accentWarm.opacity(0.6))
                }
        }
    }

    private func categoryLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "self_care":   return "Self care"
        case "mindfulness": return "Mindful"
        case "movement":    return "Movement"
        case "creative":    return "Creative"
        case "nutrition":   return "Nutrition"
        case "social":      return "Social"
        default:
            return raw.prefix(1).uppercased() + raw.dropFirst()
        }
    }

    // MARK: Wellness

    @ViewBuilder
    private var wellnessSection: some View {
        sectionCard(title: "WELLNESS") {
            if let hbi = payload.hbiAdjusted {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(hbi.rounded()))")
                            .font(AppTypography.statDisplay)
                            .tracking(AppTypography.statDisplayTracking)
                            .foregroundStyle(DesignColors.text)
                        Text("%")
                            .font(.raleway("Bold", size: 16, relativeTo: .title3))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    Text(trendLabel)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(DesignColors.textSecondary)
                }
            } else {
                Text("No wellness score recorded.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
    }

    private var trendLabel: String {
        guard let trend = payload.hbiTrendVsBaseline else {
            return "your \(payload.phase.displayName.lowercased()) score"
        }
        let rounded = trend.rounded()
        if rounded >= 1 {
            return "+\(Int(rounded)) above your \(payload.phase.displayName.lowercased()) average"
        }
        if rounded <= -1 {
            return "\(Int(rounded)) below your \(payload.phase.displayName.lowercased()) average"
        }
        return "steady with your \(payload.phase.displayName.lowercased()) average"
    }

    // MARK: Recap link

    @ViewBuilder
    private var recapLink: some View {
        Button(action: { onOpenRecap?() }) {
            HStack {
                Text("Read Cycle \(payload.cycleNumber) recap")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.text)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignColors.accentWarmText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignColors.cardWarm)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section card helper

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(AppTypography.cardEyebrow)
                .tracking(AppTypography.cardEyebrowTracking)
                .foregroundStyle(DesignColors.textSecondary)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetCardStyle(cornerRadius: 22, interactive: false)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DesignColors.text.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Formatting

    private var dateHeading: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: payload.date)
    }
}
