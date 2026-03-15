import Inject
import SwiftUI

// MARK: - Auth Choice View

public struct AuthChoiceView: View {
    @ObserveInjection var inject

    public let onEmailTapped: () -> Void
    public let onGoogleTapped: () -> Void
    public let onAppleTapped: () -> Void
    public let onGuestTapped: () -> Void
    public let onBack: (() -> Void)?

    @State private var showContent = false
    @State private var showButtons = false

    public init(
        onEmailTapped: @escaping () -> Void,
        onGoogleTapped: @escaping () -> Void,
        onAppleTapped: @escaping () -> Void,
        onGuestTapped: @escaping () -> Void,
        onBack: (() -> Void)? = nil
    ) {
        self.onEmailTapped = onEmailTapped
        self.onGoogleTapped = onGoogleTapped
        self.onAppleTapped = onAppleTapped
        self.onGuestTapped = onGuestTapped
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = max(24, min(48, geometry.size.width * 0.07))

            ZStack {
                GradientBackground()

                VStack(spacing: 0) {
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    // Back button
                    HStack {
                        if let onBack {
                            GlassBackButton(action: onBack)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Content
                    VStack(spacing: 32) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignColors.accent.opacity(0.4),
                                            DesignColors.accentWarm.opacity(0.6),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)

                            Image(systemName: "lock.shield")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.5)

                        VStack(spacing: 12) {
                            Text("Save Your Progress")
                                .font(.custom("Raleway-Bold", size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            DesignColors.text,
                                            DesignColors.textPrincipal,
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .multilineTextAlignment(.center)

                            Text("Create an account to keep your data\nsafe and synced across devices")
                                .font(.custom("Raleway-Regular", size: 15))
                                .foregroundColor(DesignColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 12)
                    }

                    Spacer().frame(height: 48)

                    // Sign up options
                    VStack(spacing: 14) {
                        // Email
                        authOptionButton(
                            icon: "envelope.fill",
                            title: "Continue with Email",
                            action: onEmailTapped
                        )

                        // Google
                        authOptionButton(
                            icon: "g.circle.fill",
                            title: "Continue with Google",
                            action: onGoogleTapped
                        )

                        // Apple
                        authOptionButton(
                            icon: "apple.logo",
                            title: "Continue with Apple",
                            action: onAppleTapped
                        )
                    }
                    .padding(.horizontal, horizontalPadding)
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 16)

                    Spacer().frame(height: 24)

                    // Guest option
                    Button(action: onGuestTapped) {
                        Text("Continue without account")
                            .font(.custom("Raleway-Medium", size: 14))
                            .foregroundColor(DesignColors.text.opacity(0.5))
                    }
                    .opacity(showButtons ? 1 : 0)

                    Spacer()

                    // Terms
                    termsView
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                        .opacity(showButtons ? 1 : 0)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showButtons = true
            }
        }
        .enableInjection()
    }

    private func authOptionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(DesignColors.accentWarm)
                    .frame(width: 24)

                Text(title)
                    .font(.custom("Raleway-SemiBold", size: 16))
                    .foregroundColor(DesignColors.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignColors.text.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
        }
    }

    private var termsView: some View {
        HStack(spacing: 0) {
            Text("By continuing, you agree to our ")
                .font(.custom("Raleway-Regular", size: 11))
                .foregroundColor(DesignColors.text.opacity(0.6))

            Button("Terms") {
                if let url = URL(string: "https://cycle.app/terms") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.custom("Raleway-Medium", size: 11))
            .foregroundColor(DesignColors.accentWarm)

            Text(" and ")
                .font(.custom("Raleway-Regular", size: 11))
                .foregroundColor(DesignColors.text.opacity(0.6))

            Button("Privacy Policy") {
                if let url = URL(string: "https://cycle.app/privacy") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.custom("Raleway-Medium", size: 11))
            .foregroundColor(DesignColors.accentWarm)
        }
        .multilineTextAlignment(.center)
    }
}
