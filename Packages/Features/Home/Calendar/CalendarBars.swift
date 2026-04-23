import ComposableArchitecture
import SwiftUI

// MARK: - Edit Period Prediction Banner

struct EditPeriodPredictionBanner: View {
    let isUpdating: Bool
    let isDone: Bool
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isDone {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(DesignColors.accentSecondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                        .scaleEffect(pulseScale)

                    Circle()
                        .stroke(DesignColors.accentWarm.opacity(0.2), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseScale * 0.9)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: 36, height: 36)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDone)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDone ? "Predictions updated" : "Updating predictions")
                    .font(.raleway("SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.text)
                    .contentTransition(.numericText())

                Text(isDone ? "Your calendar is up to date" : "Analyzing your cycle patterns...")
                    .font(.raleway("Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textSecondary)
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignColors.accent.opacity(0.15),
                                    DesignColors.roseTaupeLight.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentSecondary.opacity(0.4),
                                    DesignColors.structure.opacity(0.2),
                                    DesignColors.accent.opacity(0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: DesignColors.accentSecondary.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .padding(.horizontal, 16)
        .onAppear {
            if !isDone {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
        }
    }
}

// MARK: - Feed Top Bar

struct FeedTopBar: View {
    @Bindable var store: StoreOf<CalendarFeature>
    @Binding var viewMode: CalendarView.CalendarViewMode
    var isCurrentMonthVisible: Bool
    var onTodayTapped: () -> Void


    var body: some View {
        HStack(spacing: 0) {
            // Left: X / Back
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if store.isEditingPeriod {
                    store.send(.editPeriodToggled, animation: .appBalanced)
                } else {
                    store.send(.dismissTapped)
                }
            } label: {
                Image(systemName: store.isEditingPeriod ? "chevron.left" : "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 44, height: 44)
                    .background {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.9), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .padding(2)
                                .offset(y: -2)
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: Month/Year toggle or edit hint
            if store.isEditingPeriod {
                Text("Tap days to mark your period")
                    .font(.raleway("Medium", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .transition(.opacity)
            } else {
                Picker("", selection: Binding(
                    get: { viewMode },
                    set: { newValue in
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewMode = newValue
                        }
                    }
                )) {
                    ForEach(CalendarView.CalendarViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .transition(.opacity)
            }

            Spacer()

            // Right: Today button — fixed width container so Month/Year stays centered
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTodayTapped()
            } label: {
                Text("Today")
                    .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .buttonStyle(.plain)
            .opacity(store.isEditingPeriod || (viewMode == .month && isCurrentMonthVisible) ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isCurrentMonthVisible)
            .allowsHitTesting(!store.isEditingPeriod && !(viewMode == .month && isCurrentMonthVisible))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.25), value: store.isEditingPeriod)
    }
}

