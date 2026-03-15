import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Authentication Feature

@Reducer
public struct AuthenticationFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var email: String
        public var password: String
        public var confirmPassword: String
        public var firstName: String
        public var lastName: String
        public var passwordVisible: Bool
        public var confirmPasswordVisible: Bool

        public var isLoading: Bool
        public var error: String?

        public var emailValidation: ValidationResult
        public var passwordValidation: ValidationResult

        public enum Mode: Equatable, Sendable {
            case login
            case register
            case forgotPassword
        }

        public init(
            mode: Mode = .login,
            email: String = "",
            password: String = "",
            confirmPassword: String = "",
            firstName: String = "",
            lastName: String = "",
            passwordVisible: Bool = false,
            confirmPasswordVisible: Bool = false,
            isLoading: Bool = false,
            error: String? = nil
        ) {
            self.mode = mode
            self.email = email
            self.password = password
            self.confirmPassword = confirmPassword
            self.firstName = firstName
            self.lastName = lastName
            self.passwordVisible = passwordVisible
            self.confirmPasswordVisible = confirmPasswordVisible
            self.isLoading = isLoading
            self.error = error
            self.emailValidation = .valid
            self.passwordValidation = .valid
        }

        // MARK: - Validation computed properties

        public var isEmailValid: Bool {
            let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
            return email.wholeMatch(of: emailRegex) != nil
        }

        public var hasMinLength: Bool { password.count >= 8 }
        public var hasUppercase: Bool { password.contains(where: { $0.isUppercase }) }
        public var hasLowercase: Bool { password.contains(where: { $0.isLowercase }) }
        public var hasDigit: Bool { password.contains(where: { $0.isNumber }) }

        public var passwordStrength: Int {
            [hasMinLength, hasUppercase, hasLowercase, hasDigit].filter { $0 }.count
        }

        public var isPasswordValid: Bool { passwordStrength >= 3 }
        public var doPasswordsMatch: Bool { password == confirmPassword }

        public var isFormValid: Bool {
            switch mode {
            case .login:
                isEmailValid && password.count >= 6
            case .register:
                isEmailValid && isPasswordValid && doPasswordsMatch && !confirmPassword.isEmpty
            case .forgotPassword:
                isEmailValid
            }
        }

        public var emailError: String? {
            guard !email.isEmpty else { return nil }
            return isEmailValid ? nil : "Invalid email format"
        }

        public var confirmPasswordError: String? {
            guard !confirmPassword.isEmpty else { return nil }
            return doPasswordsMatch ? nil : "Passwords don't match"
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)

        case setMode(State.Mode)
        case togglePasswordVisibility
        case toggleConfirmPasswordVisibility
        case loginTapped
        case registerTapped
        case forgotPasswordTapped
        case googleSignInTapped
        case clearError

        case loginResponse(Result<AuthUser, Error>)
        case registerResponse(Result<AuthUser, Error>)
        case forgotPasswordResponse(Result<Void, Error>)

        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didAuthenticate
        }
    }

    @Dependency(\.firebaseAuthClient) var firebaseAuth
    @Dependency(\.sessionClient) var sessionClient

    public init() {}

    // Map Firebase errors to user-friendly messages
    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 17008: return "Invalid email format"
        case 17009: return "Incorrect password"
        case 17011: return "No account found with this email"
        case 17007: return "This email is already registered"
        case 17026: return "Password must be at least 6 characters"
        case 17020: return "Network error. Please check your connection"
        default: return error.localizedDescription
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.email):
                state.emailValidation = Validation.email(state.email)
                state.error = nil
                return .none

            case .binding(\.password):
                state.passwordValidation = Validation.password(state.password)
                state.error = nil
                return .none

            case .binding(\.mode):
                // Clear confirm password when switching modes
                state.confirmPassword = ""
                state.error = nil
                return .none

            case .binding:
                state.error = nil
                return .none

            case .setMode(let mode):
                state.mode = mode
                state.confirmPassword = ""
                state.error = nil
                return .none

            case .togglePasswordVisibility:
                state.passwordVisible.toggle()
                return .none

            case .toggleConfirmPasswordVisibility:
                state.confirmPasswordVisible.toggle()
                return .none

            case .loginTapped:
                guard state.isFormValid else { return .none }
                state.isLoading = true
                state.error = nil

                return .run { [email = state.email, password = state.password] send in
                    let result = await Result {
                        try await firebaseAuth.signIn(email, password)
                    }
                    await send(.loginResponse(result))
                }

            case .loginResponse(.success(let authUser)):
                state.isLoading = false
                // Create session from Firebase user
                return .run { send in
                    let token = try await firebaseAuth.getIDToken()
                    let session = Session(
                        id: Session.ID(authUser.uid),
                        accessToken: token,
                        refreshToken: "",  // Firebase handles refresh internally
                        expiresAt: Date().addingTimeInterval(3600),  // 1 hour
                        user: User(
                            id: User.ID(authUser.uid),
                            email: authUser.email ?? "",
                            firstName: authUser.displayName,
                            lastName: nil
                        )
                    )
                    try await sessionClient.setSession(session)
                    await send(.delegate(.didAuthenticate))
                } catch: { error, send in
                    await send(.loginResponse(.failure(error)))
                }

            case .loginResponse(.failure(let error)):
                state.isLoading = false
                state.error = mapFirebaseError(error)
                return .none

            case .registerTapped:
                guard state.isFormValid else { return .none }
                state.isLoading = true
                state.error = nil

                let email = state.email
                let password = state.password

                return .run { send in
                    let result = await Result {
                        try await firebaseAuth.signUp(email, password)
                    }
                    await send(.registerResponse(result))
                }

            case .registerResponse(.success(let authUser)):
                state.isLoading = false
                return .run { send in
                    let token = try await firebaseAuth.getIDToken()
                    let session = Session(
                        id: Session.ID(authUser.uid),
                        accessToken: token,
                        refreshToken: "",
                        expiresAt: Date().addingTimeInterval(3600),
                        user: User(
                            id: User.ID(authUser.uid),
                            email: authUser.email ?? "",
                            firstName: authUser.displayName,
                            lastName: nil
                        )
                    )
                    try await sessionClient.setSession(session)
                    await send(.delegate(.didAuthenticate))
                } catch: { error, send in
                    await send(.registerResponse(.failure(error)))
                }

            case .registerResponse(.failure(let error)):
                state.isLoading = false
                state.error = mapFirebaseError(error)
                return .none

            case .forgotPasswordTapped:
                guard state.isEmailValid else {
                    state.emailValidation = .invalid("Please enter a valid email")
                    return .none
                }
                state.isLoading = true
                state.error = nil

                return .run { [email = state.email] send in
                    let result = await Result {
                        try await firebaseAuth.resetPassword(email)
                    }
                    await send(.forgotPasswordResponse(result))
                }

            case .forgotPasswordResponse(.success):
                state.isLoading = false
                state.mode = .login
                state.error = nil
                // Could show a success message here
                return .none

            case .forgotPasswordResponse(.failure(let error)):
                state.isLoading = false
                state.error = mapFirebaseError(error)
                return .none

            case .googleSignInTapped:
                // TODO: Implement Google Sign In
                return .none

            case .clearError:
                state.error = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Authentication View

public struct AuthenticationView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<AuthenticationFeature>
    @FocusState private var focusedField: Field?
    var onBack: (() -> Void)?

    private enum Field: Hashable {
        case email, password, confirmPassword
    }

    public init(store: StoreOf<AuthenticationFeature>, onBack: (() -> Void)? = nil) {
        self.store = store
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 640

            let sectionSpacing: CGFloat = 28
            let fieldSpacing: CGFloat = 14
            let horizontalPadding: CGFloat = max(20, min(48, geometry.size.width * 0.07))

            ZStack {
                GradientBackground()

                VStack(spacing: 0) {
                    Spacer().frame(height: geometry.safeAreaInsets.top + 16)

                    // Back button — matching OnboardingHeader layout
                    HStack {
                        if let onBack {
                            GlassBackButton(action: onBack)
                        } else {
                            Color.clear.frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Title
                    Text(store.mode == .login ? "Welcome Back" : "Create Account")
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

                    Spacer().frame(height: sectionSpacing)

                    // Form Fields
                    VStack(spacing: fieldSpacing) {
                        AuthGlassTextField(
                            text: $store.email,
                            placeholder: "Email",
                            isFocused: focusedField == .email,
                            error: store.emailError,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                        AuthGlassTextField(
                            text: $store.password,
                            placeholder: "Password",
                            isFocused: focusedField == .password,
                            isPassword: true,
                            passwordVisible: store.passwordVisible,
                            onPasswordVisibilityToggle: {
                                store.send(.togglePasswordVisibility)
                            }
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(store.mode == .login ? .done : .next)
                        .onSubmit {
                            if store.mode == .login {
                                focusedField = nil
                                store.send(.loginTapped)
                            } else {
                                focusedField = .confirmPassword
                            }
                        }

                        if store.mode == .register {
                            if !store.password.isEmpty {
                                PasswordStrengthIndicator(strength: store.passwordStrength)
                                    .padding(.horizontal, 4)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            AuthGlassTextField(
                                text: $store.confirmPassword,
                                placeholder: "Confirm Password",
                                isFocused: focusedField == .confirmPassword,
                                isPassword: true,
                                passwordVisible: store.confirmPasswordVisible,
                                onPasswordVisibilityToggle: {
                                    store.send(.toggleConfirmPasswordVisibility)
                                },
                                error: store.confirmPasswordError
                            )
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                                store.send(.registerTapped)
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                    Spacer().frame(height: 8)

                    // Error message
                    if let error = store.error {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                            Text(error)
                                .font(.custom("Raleway-Medium", size: 14))
                        }
                        .foregroundColor(Color(hex: 0xE57373))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: 0xE57373).opacity(0.1))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color(hex: 0xE57373).opacity(0.3), lineWidth: 1)
                                }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onTapGesture {
                            store.send(.clearError)
                        }
                    }

                    Spacer().frame(height: sectionSpacing)

                    // Submit button
                    if store.isLoading {
                        ZStack {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .frame(width: isSmallScreen ? 200 : 220, height: 55)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

                            ProgressView()
                                .tint(DesignColors.text)
                        }
                    } else {
                        GlassButton(
                            store.mode == .login ? "Log In" : "Create Account",
                            width: isSmallScreen ? 200 : 220
                        ) {
                            store.send(store.mode == .login ? .loginTapped : .registerTapped)
                        }
                        .opacity(store.isFormValid ? 1 : 0.5)
                        .disabled(!store.isFormValid)
                    }

                    Spacer()

                    // Terms and Privacy
                    termsAndPrivacyView
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                }
            }
            .ignoresSafeArea()
            .ignoresSafeArea(.keyboard)
            .onTapGesture {
                focusedField = nil
            }
        }
        .disabled(store.isLoading)
        .enableInjection()
    }

    private var termsAndPrivacyView: some View {
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

// MARK: - Glass Tab Switch

private struct AuthGlassTabSwitch: View {
    let isSignIn: Bool
    let onModeChange: (Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / 2

            ZStack {
                // Background glass
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.5),
                                    ],
                                    center: .center
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    .allowsHitTesting(false)

                // Sliding indicator
                HStack {
                    if isSignIn { Spacer() }

                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: 0xFDD2C9).opacity(0),
                                            Color(hex: 0xFDD2C9).opacity(0.4),
                                        ],
                                        startPoint: UnitPoint(x: 0.8, y: 0.2),
                                        endPoint: UnitPoint(x: 0.2, y: 0.8)
                                    )
                                )

                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    AngularGradient(
                                        colors: [
                                            Color.white.opacity(0.7),
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.7),
                                        ],
                                        center: .center
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .frame(width: tabWidth - 8)
                        .padding(4)

                    if !isSignIn { Spacer() }
                }
                .allowsHitTesting(false)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSignIn)

                // Tab labels
                HStack(spacing: 0) {
                    Button {
                        onModeChange(false)
                    } label: {
                        Text("Sign Up")
                            .font(.custom(isSignIn ? "Raleway-Regular" : "Raleway-SemiBold", size: 16))
                            .foregroundColor(isSignIn ? DesignColors.text.opacity(0.5) : DesignColors.text)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        onModeChange(true)
                    } label: {
                        Text("Sign In")
                            .font(.custom(isSignIn ? "Raleway-SemiBold" : "Raleway-Regular", size: 16))
                            .foregroundColor(isSignIn ? DesignColors.text : DesignColors.text.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 52)
    }
}

// MARK: - Auth Glass Text Field

private struct AuthGlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let isFocused: Bool
    var isPassword: Bool = false
    var passwordVisible: Bool = false
    var onPasswordVisibilityToggle: (() -> Void)? = nil
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    private var hasError: Bool { error != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Group {
                    if isPassword && !passwordVisible {
                        SecureField("", text: $text, prompt: placeholderText)
                    } else {
                        TextField("", text: $text, prompt: placeholderText)
                            .keyboardType(keyboardType)
                    }
                }
                .font(.custom("Raleway-SemiBold", size: 16))
                .foregroundColor(DesignColors.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(textContentType)

                // Password visibility toggle
                if isPassword, let toggle = onPasswordVisibilityToggle {
                    Button(action: toggle) {
                        Text(passwordVisible ? "Hide" : "Show")
                            .font(.custom("Raleway-Medium", size: 13))
                            .foregroundColor(DesignColors.textPrincipal)
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 57)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)

                    // Peach gradient
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xFDD2C9).opacity(0),
                                    Color(hex: 0xFDD2C9).opacity(0.3),
                                ],
                                startPoint: UnitPoint(x: 0.8, y: 0.2),
                                endPoint: UnitPoint(x: 0.2, y: 0.8)
                            )
                        )

                    // Inner glow
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: 0xF2F2F2).opacity(0.3),
                                    Color(hex: 0xF2F2F2).opacity(0.1),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            AngularGradient(
                                colors: borderColors,
                                center: .center
                            ),
                            lineWidth: isFocused || hasError ? 1.5 : 1
                        )

                    // Top highlight
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.12)
                            )
                        )
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 0)

            // Error message
            if let error = error {
                Text(error)
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundColor(Color(hex: 0xE57373))
                    .padding(.leading, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasError)
    }

    private var placeholderText: Text {
        Text(placeholder)
            .font(.custom("Raleway-Medium", size: 16))
            .foregroundColor(DesignColors.text.opacity(0.5))
    }

    private var borderColors: [Color] {
        let alpha = isFocused ? 0.7 : (hasError ? 0.8 : 0.5)
        let baseColor = hasError ? Color(hex: 0xE57373) : Color.white

        return [
            baseColor.opacity(alpha),
            baseColor.opacity(alpha * 0.6),
            baseColor.opacity(alpha * 0.3),
            baseColor.opacity(alpha * 0.15),
            baseColor.opacity(alpha * 0.3),
            baseColor.opacity(alpha * 0.7),
            baseColor.opacity(alpha),
        ]
    }
}

// MARK: - Password Strength Indicator

private struct PasswordStrengthIndicator: View {
    let strength: Int

    private var strengthText: String {
        switch strength {
        case 0...1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        default: return "Strong"
        }
    }

    private var strengthColor: Color {
        switch strength {
        case 0...1: return Color(hex: 0xE57373)
        case 2: return Color(hex: 0xFFB74D)
        case 3: return Color(hex: 0x81C784)
        default: return Color(hex: 0x4CAF50)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // Progress bars
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < strength ? strengthColor : DesignColors.text.opacity(0.1))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: strength)
            }

            Spacer().frame(width: 8)

            Text(strengthText)
                .font(.custom("Raleway-Medium", size: 11))
                .foregroundColor(strengthColor)
                .animation(.easeInOut(duration: 0.3), value: strength)
        }
    }
}

// MARK: - Gradient Divider

private struct GradientDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: DesignColors.text.opacity(0.08), location: 0.15),
                        .init(color: DesignColors.text.opacity(0.15), location: 0.5),
                        .init(color: DesignColors.text.opacity(0.08), location: 0.85),
                        .init(color: Color.clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

// MARK: - Preview

#Preview("Sign In") {
    AuthenticationView(
        store: .init(initialState: AuthenticationFeature.State(mode: .login)) {
            AuthenticationFeature()
        }
    )
}

#Preview("Sign Up") {
    AuthenticationView(
        store: .init(initialState: AuthenticationFeature.State(mode: .register)) {
            AuthenticationFeature()
        }
    )
}

#Preview("Sign Up - With Data") {
    AuthenticationView(
        store: .init(
            initialState: AuthenticationFeature.State(
                mode: .register,
                email: "test@example.com",
                password: "Password1"
            )
        ) {
            AuthenticationFeature()
        }
    )
}

#Preview("Sign In - Loading") {
    AuthenticationView(
        store: .init(
            initialState: AuthenticationFeature.State(
                mode: .login,
                email: "test@example.com",
                password: "password123",
                isLoading: true
            )
        ) {
            AuthenticationFeature()
        }
    )
}

#Preview("Sign In - Error") {
    AuthenticationView(
        store: .init(
            initialState: AuthenticationFeature.State(
                mode: .login,
                email: "invalid-email",
                password: "wrong"
            )
        ) {
            AuthenticationFeature()
        }
    )
}
