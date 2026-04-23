import SwiftUI
import UIKit

// MARK: - CycleHeroView › Expanded + Collapsed content
//
// The two hero layout states — full expanded card and the compact
// collapsed header — extracted from CycleHeroView.swift so the main
// file can stay focused on state + computed display props.

extension CycleHeroView {

    @ViewBuilder
    var expandedContent: some View {
        VStack(spacing: 0) {
            // Top bar: profile + day/phase info + calendar button
            HStack(spacing: 0) {
                // Left-aligned month meta tag.
                Text(monthLabel.uppercased())
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.8)
                    .foregroundColor(textOnHeroColor.opacity(0.55))
                    .padding(.leading, 16)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onCalendarTapped?()
                } label: {
                    Group {
                        if isRefreshing {
                            ProgressView()
                                .tint(DesignColors.accentWarm)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "calendar")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(DesignColors.accentWarm)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isRefreshing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Calendar")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .opacity(staggeredOpacity(fadeEnd: 0.60))

            // Week calendar
            MiniCycleCalendar(
                cycle: cycle,
                selectedDate: $selectedDate,
                embedded: true
            )
            .padding(.top, -8)
            .opacity(staggeredOpacity(fadeEnd: 0.55))
            .allowsHitTesting(progress < 0.3)

            // Nyra on the LEFT with a chat-bubble message on the RIGHT
            // — same asymmetric "speaker" corner radius as iMessage, so
            // the wellness line reads as something she's saying. Status
            // text + action buttons sit below the bubble as meta.
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .top, spacing: 10) {
                    // Unmount the orb entirely when an overlay is on
                    // top of Home — `NyraOrb` runs a 30Hz TimelineView
                    // plus several `repeatForever` animations, all of
                    // which keep driving the SwiftUI graph even when
                    // visually hidden. Instruments showed this as the
                    // dominant source of `ViewGraph.beginNextUpdate`
                    // work during Cycle Insights scroll. A clear
                    // placeholder preserves the hero layout so there
                    // is no reflow when the overlay dismisses.
                    Group {
                        if isBehindOverlay {
                            Color.clear.frame(width: 104, height: 104)
                        } else {
                            NyraOrb(
                                size: 104,
                                mood: .speaking,
                                active: progress < 0.5
                            )
                        }
                    }
                    .opacity(staggeredOpacity(fadeEnd: 0.55))
                    .accessibilityHidden(true)
                    .padding(.top, -4)

                    VStack(alignment: .trailing, spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignColors.structure.opacity(0.3))
                            .frame(width: 160, height: 16)
                            .opacity(isLoadingWellnessMessage ? 1 : 0)

                        Text(aiWellnessMessage ?? wellnessMessage)
                            .font(.raleway("MediumItalic", size: 15, relativeTo: .body))
                            .foregroundColor(textOnHeroColor.opacity(0.88))
                            .multilineTextAlignment(.leading)
                            .lineLimit(5)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(isLoadingWellnessMessage ? 0 : 1)
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 14)
                    .padding(.top, 11)
                    .padding(.bottom, 16)
                    .background(
                        ChatBubble(radius: 20, tailSize: 14)
                            .fill(Color.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                    .overlay(
                        ChatBubble(radius: 20, tailSize: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), DesignColors.accentWarm.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: aiWellnessMessage)
                    .opacity(staggeredOpacity(fadeEnd: 0.50))

                        leftActionButtons
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.top, 2)
            .padding(.bottom, 14)
            .opacity(staggeredOpacity(fadeEnd: 0.40))

            Spacer(minLength: 0)
        }
    }

    // MARK: - Left-column action buttons

    @ViewBuilder
    var leftActionButtons: some View {
        HStack(spacing: 6) {
                if let onLogPeriod, !isConfirmedPeriodDay,
                   cycle.isLate || isPredictedPeriod || isLatePrediction || isLateForDate || displayPhase == .menstrual {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLogPeriod()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .accessibilityHidden(true)
                            Text("Log period")
                                .font(.raleway("SemiBold", size: 15, relativeTo: .callout))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.2), Color.clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                }
                                .shadow(color: DesignColors.accentWarm.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                    .opacity(isRefreshing ? 0.5 : 1)
                }

                if let onEditPeriod {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onEditPeriod()
                    } label: {
                        Text("My cycle")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .callout))
                            .foregroundColor(textOnHeroColor)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background {
                                ZStack {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    // Top shine
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.9), Color.clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                        .padding(2)
                                    // Border
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .shadow(color: DesignColors.accentWarm.opacity(0.12), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 14)
            .opacity(staggeredOpacity(fadeEnd: 0.40))
        }
    // MARK: - Collapsed Content (compact header)

    @ViewBuilder
    var collapsedContent: some View {
        HStack(spacing: 0) {
            // Status summary
            VStack(alignment: .leading, spacing: 3) {
                Text(collapsedHeadline)
                    .font(.raleway("Bold", size: 17, relativeTo: .body))
                    .tracking(-0.2)
                    .foregroundColor(textOnHeroColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Calendar button — no background
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCalendarTapped?()
            } label: {
                Group {
                    if isRefreshing {
                        ProgressView()
                            .tint(DesignColors.accentWarm)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "calendar")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(DesignColors.accentWarm)
                    }
                }
                .frame(width: 44, height: 44)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isRefreshing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Calendar")
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Collapsed Text

    var collapsedHeadline: String {
        if isRefreshing { return "Updating..." }
        if cycle.isLate {
            // If today itself is a predicted period day, the period is
            // "expected today" even when the cycle math treats the
            // window as having opened a day earlier.
            let today = Calendar.current.startOfDay(for: Date())
            let todayKey = cycle.dateKey(for: today)
            if cycle.predictedDays.contains(todayKey) {
                return "Period expected today"
            }
            let late = cycle.effectiveDaysLate
            if late <= 0 { return "Period expected today" }
            if late == 1 { return "Period expected yesterday" }
            return "Period expected \(late) days ago"
        }

        if isPeriod && !isPredictedPeriod {
            let bleed = cycle.bleedingDays
            let periodDay = max(1, displayCycleDay)
            return "Period · Day \(periodDay) of \(bleed)"
        }

        if cycle.fertileWindowActive || isFertileDay {
            return "Fertile window"
        }

        if displayPhase == .ovulatory {
            return "Peak day"
        }

        let days = daysUntilPeriod
        if days == 1 { return "Period in 1 day" }
        if days > 0 && days <= 3 { return "Period in \(days) days" }
        if days > 3 && days <= 14 { return "\(days) days until period" }

        return phaseLabel
    }

    var collapsedDetail: String {
        ""
    }

}
