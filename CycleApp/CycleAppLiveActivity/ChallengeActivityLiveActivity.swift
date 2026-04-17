import ActivityKit
import SwiftUI
import WidgetKit

private let accentWarm = Color(red: 193 / 255, green: 143 / 255, blue: 125 / 255)
private let textCocoa = Color(red: 92 / 255, green: 74 / 255, blue: 59 / 255)
private let textPrincipal = Color(red: 122 / 255, green: 95 / 255, blue: 80 / 255)

private func categoryIcon(_ category: String) -> String {
    switch category.lowercased() {
    case "movement": return "figure.walk"
    case "mindfulness": return "brain.head.profile"
    case "self_care": return "heart.fill"
    case "creative": return "paintbrush.fill"
    case "nutrition": return "leaf.fill"
    case "social": return "person.2.fill"
    default: return "star.fill"
    }
}

struct ChallengeActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChallengeActivityAttributes.self) { context in
            let interval = context.state.timerStart...context.state.timerEnd
            // Lock Screen
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(context.state.timerEnd, style: .timer)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Spacer()
                    Image(systemName: categoryIcon(context.attributes.challengeCategory))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text("cycle")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(accentWarm)
                        Text(context.attributes.challengeTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                ProgressView(timerInterval: interval, countsDown: true)
                    .progressViewStyle(.linear)
                    .tint(accentWarm)
                    .labelsHidden()
                Link(destination: URL(string: "cycle://challenge/done")!) {
                    Text("I'm done")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accentWarm, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .activityBackgroundTint(textCocoa.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.challengeTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(context.attributes.cyclePhase.capitalized + " phase")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.timerStart...context.state.timerEnd, countsDown: true, showsHours: false)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(accentWarm)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.timerStart...context.state.timerEnd, countsDown: true)
                        .progressViewStyle(.linear)
                        .tint(accentWarm)
                        .labelsHidden()
                }
            } compactLeading: {
                Image(systemName: categoryIcon(context.attributes.challengeCategory))
                    .font(.caption2)
                    .foregroundStyle(accentWarm)
            } compactTrailing: {
                Text(timerInterval: context.state.timerStart...context.state.timerEnd, countsDown: true, showsHours: false)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 42)
            } minimal: {
                Circle()
                    .fill(accentWarm)
                    .frame(width: 10, height: 10)
            }
            .contentMargins(.all, 24, for: .expanded)
        }
    }
}
