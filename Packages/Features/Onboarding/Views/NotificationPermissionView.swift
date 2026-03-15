import Inject
import SwiftUI
import UserNotifications

// MARK: - Notification Permission View

public struct NotificationPermissionView: View {
    @ObserveInjection var inject
    public let onEnable: (Int, Int) -> Void
    public let onSkip: () -> Void
    public let onBack: (() -> Void)?

    @State private var isRequestingPermission = false
    @State private var animateIn = false
    @State private var selectedHour: Int = 20
    @State private var selectedMinute: Int = 0

    public init(
        onEnable: @escaping (Int, Int) -> Void,
        onSkip: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.onEnable = onEnable
        self.onSkip = onSkip
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    OnboardingHeader(
                        currentStep: 9,
                        totalSteps: 11,
                        onBack: onBack
                    )

                    Spacer()

                    // Icon
                    Image(systemName: "bell.badge.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                        .foregroundStyle(DesignColors.accentWarm)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(animateIn ? 1 : 0.8)
                        .opacity(animateIn ? 1 : 0)

                    Spacer().frame(height: 28)

                    // Title
                    Text("Daily Check-in")
                        .font(.custom("Raleway-Bold", size: 28))
                        .foregroundColor(DesignColors.text)
                        .opacity(animateIn ? 1 : 0)

                    Spacer().frame(height: 12)

                    Text("A daily reminder to log how you feel,\nso your insights stay accurate.")
                        .font(.custom("Raleway-Regular", size: 16))
                        .foregroundColor(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .opacity(animateIn ? 1 : 0)

                    Spacer().frame(height: 44)

                    // Time picker — single clean row
                    HStack(spacing: 8) {
                        Text("Remind me at")
                            .font(.custom("Raleway-Medium", size: 16))
                            .foregroundColor(DesignColors.text)

                        timePickerView
                    }
                    .opacity(animateIn ? 1 : 0)

                    Spacer()

                    // Buttons
                    VStack(spacing: 16) {
                        if isRequestingPermission {
                            ProgressView()
                                .frame(height: 55)
                        } else {
                            GlassButton("Enable Reminders", showArrow: false) {
                                requestNotificationPermission()
                            }
                        }

                        Button {
                            onSkip()
                        } label: {
                            Text("Not Now")
                                .font(.custom("Raleway-Medium", size: 15))
                                .foregroundColor(DesignColors.textSecondary)
                        }
                        .disabled(isRequestingPermission)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + AppLayout.bottomOffset)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
        .enableInjection()
    }

    @ViewBuilder
    private var timePickerView: some View {
        HStack(spacing: 4) {
            Picker("Hour", selection: $selectedHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignColors.accentWarm)

            Text(":")
                .font(.custom("Raleway-Bold", size: 18))
                .foregroundColor(DesignColors.text)

            Picker("Minute", selection: $selectedMinute) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignColors.accentWarm)
        }
    }

    private func requestNotificationPermission() {
        isRequestingPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                isRequestingPermission = false
                onEnable(selectedHour, selectedMinute)
            }
        }
    }
}

// MARK: - Preview

#Preview("Notification Permission") {
    NotificationPermissionView(
        onEnable: { hour, minute in print("Enable: \(hour):\(minute)") },
        onSkip: { print("Skip tapped") },
        onBack: { print("Back tapped") }
    )
}
