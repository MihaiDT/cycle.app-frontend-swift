import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Daily Check-In Feature

@Reducer
public struct DailyCheckInFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var energyLevel: Double = 3
        public var stressLevel: Double = 3
        public var sleepQuality: Double = 3
        public var moodLevel: Double = 3
        public var notes: String = ""
        public var isSubmitting: Bool = false
        public var error: String?

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case submitTapped
        case submitResponse(Result<DailyReportResponse, Error>)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didCompleteCheckIn(DailyReportResponse)
        }
    }

    @Dependency(\.hbiLocal) var hbiLocal
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                state.isSubmitting = true
                state.error = nil
                let request = DailyReportRequest(
                    energyLevel: Int(state.energyLevel),
                    stressLevel: Int(state.stressLevel),
                    sleepQuality: Int(state.sleepQuality),
                    moodLevel: Int(state.moodLevel),
                    notes: state.notes.isEmpty ? nil : state.notes
                )
                return .run { send in
                    let result = await Result {
                        try await hbiLocal.submitDailyReport(request)
                    }
                    await send(.submitResponse(result))
                }

            case .submitResponse(.success(let response)):
                state.isSubmitting = false
                return .run { send in
                    await send(.delegate(.didCompleteCheckIn(response)))
                    await dismiss()
                }

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error.localizedDescription
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Daily Check-In View

public struct DailyCheckInView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<DailyCheckInFeature>

    @State private var showContent = false

    public init(store: StoreOf<DailyCheckInFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(DesignColors.divider)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, AppLayout.spacingL)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppLayout.spacingL) {
                    // Title
                    VStack(spacing: 8) {
                        Text("How are you feeling?")
                            .font(.custom("Raleway-Bold", size: 26))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DesignColors.text, DesignColors.textPrincipal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Take a moment to check in with yourself")
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 12)

                    // Sliders
                    VStack(spacing: 20) {
                        checkInSlider(
                            label: "Energy",
                            icon: "bolt.fill",
                            value: $store.energyLevel,
                            labels: ["Low", "Medium", "High"]
                        )

                        checkInSlider(
                            label: "Mood",
                            icon: "face.smiling.fill",
                            value: $store.moodLevel,
                            labels: ["Low", "Neutral", "Great"]
                        )

                        checkInSlider(
                            label: "Sleep",
                            icon: "moon.fill",
                            value: $store.sleepQuality,
                            labels: ["Poor", "Fair", "Restful"]
                        )

                        checkInSlider(
                            label: "Stress",
                            icon: "leaf.fill",
                            value: $store.stressLevel,
                            labels: ["Calm", "Some", "Intense"]
                        )
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 16)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.custom("Raleway-Medium", size: 13))
                            .foregroundColor(DesignColors.textSecondary)

                        TextField("How's your day going?", text: $store.notes, axis: .vertical)
                            .font(.custom("Raleway-Regular", size: 15))
                            .foregroundColor(DesignColors.text)
                            .lineLimit(3...5)
                            .padding(AppLayout.spacingM)
                            .background {
                                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    }
                            }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 16)

                    // Error
                    if let error = store.error {
                        Text(error)
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundColor(.red.opacity(0.8))
                    }

                    // Submit button
                    Button(action: { store.send(.submitTapped) }) {
                        HStack(spacing: 8) {
                            if store.isSubmitting {
                                ProgressView()
                                    .tint(DesignColors.text)
                            }
                            Text(store.isSubmitting ? "Saving..." : "Save Check-in")
                                .font(.custom("Raleway-SemiBold", size: 17))
                                .foregroundColor(DesignColors.text)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: AppLayout.buttonHeight)
                        .glassEffectCapsule()
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isSubmitting)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 16)

                    VerticalSpace.l
                }
                .padding(.horizontal, AppLayout.horizontalPadding)
            }
        }
        .background(DesignColors.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
        .enableInjection()
    }

    // MARK: - Slider Component

    @ViewBuilder
    private func checkInSlider(
        label: String,
        icon: String,
        value: Binding<Double>,
        labels: [String]
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignColors.accentWarm)

                Text(label)
                    .font(.custom("Raleway-SemiBold", size: 15))
                    .foregroundColor(DesignColors.text)

                Spacer()

                Text("\(Int(value.wrappedValue))/5")
                    .font(.custom("Raleway-Bold", size: 15))
                    .foregroundColor(DesignColors.accentWarm)
            }

            Slider(value: value, in: 1...5, step: 1)
                .tint(DesignColors.accentWarm)
                .onChange(of: value.wrappedValue) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

            HStack {
                Text(labels.first ?? "")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textPlaceholder)
                Spacer()
                Text(labels.last ?? "")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(DesignColors.textPlaceholder)
            }
        }
        .padding(AppLayout.spacingM)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusM)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
    }
}
