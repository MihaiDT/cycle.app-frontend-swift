import ComposableArchitecture
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
            isLoading: Bool = false,
            error: String? = nil
        ) {
            self.mode = mode
            self.email = email
            self.password = password
            self.confirmPassword = confirmPassword
            self.firstName = firstName
            self.lastName = lastName
            self.isLoading = isLoading
            self.error = error
            self.emailValidation = .valid
            self.passwordValidation = .valid
        }

        public var isFormValid: Bool {
            switch mode {
            case .login:
                email.isNotBlank && password.isNotBlank
            case .register:
                email.isNotBlank && password.isNotBlank && password == confirmPassword
            case .forgotPassword:
                email.isValidEmail
            }
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)

        case setMode(State.Mode)
        case loginTapped
        case registerTapped
        case forgotPasswordTapped
        case clearError

        case loginResponse(Result<Session, Error>)
        case registerResponse(Result<Session, Error>)
        case forgotPasswordResponse(Result<Void, Error>)

        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didAuthenticate
        }
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.sessionClient) var sessionClient

    public init() {}

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

            case .binding:
                state.error = nil
                return .none

            case .setMode(let mode):
                state.mode = mode
                state.error = nil
                return .none

            case .loginTapped:
                guard state.isFormValid else { return .none }
                state.isLoading = true
                state.error = nil

                return .run { [email = state.email, password = state.password] send in
                    let endpoint = AuthEndpoints.login(email: email, password: password)
                    let result = await Result {
                        try await apiClient.send(endpoint) as Session
                    }
                    await send(.loginResponse(result))
                }

            case .loginResponse(.success(let session)):
                state.isLoading = false
                return .run { send in
                    try await sessionClient.setSession(session)
                    await send(.delegate(.didAuthenticate))
                }

            case .loginResponse(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .registerTapped:
                guard state.isFormValid else { return .none }
                state.isLoading = true
                state.error = nil

                let email = state.email
                let password = state.password
                let firstName = state.firstName.isBlank ? nil : state.firstName
                let lastName = state.lastName.isBlank ? nil : state.lastName

                return .run { send in
                    let endpoint = AuthEndpoints.register(
                        email: email,
                        password: password,
                        firstName: firstName,
                        lastName: lastName
                    )
                    let result = await Result {
                        try await apiClient.send(endpoint) as Session
                    }
                    await send(.registerResponse(result))
                }

            case .registerResponse(.success(let session)):
                state.isLoading = false
                return .run { send in
                    try await sessionClient.setSession(session)
                    await send(.delegate(.didAuthenticate))
                }

            case .registerResponse(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .forgotPasswordTapped:
                guard state.email.isValidEmail else {
                    state.emailValidation = .invalid("Please enter a valid email")
                    return .none
                }
                state.isLoading = true
                state.error = nil

                return .run { [email = state.email] send in
                    let endpoint = AuthEndpoints.forgotPassword(email: email)
                    let result = await Result {
                        try await apiClient.send(endpoint)
                    }
                    await send(.forgotPasswordResponse(result))
                }

            case .forgotPasswordResponse(.success):
                state.isLoading = false
                state.mode = .login
                return .none

            case .forgotPasswordResponse(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
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
    @Bindable var store: StoreOf<AuthenticationFeature>

    public init(store: StoreOf<AuthenticationFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerView

                    formView

                    actionsView
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .disabled(store.isLoading)
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text(headerTitle)
                .font(.title.bold())

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private var headerTitle: String {
        switch store.mode {
        case .login: " Hot Bogdan !"
        case .register: "Create Account"
        case .forgotPassword: "Reset Password"
        }
    }

    private var headerSubtitle: String {
        switch store.mode {
        case .login: "Sign in to continue"
        case .register: "Sign up to get started"
        case .forgotPassword: "Enter your email to receive reset instructions"
        }
    }

    private var formView: some View {
        VStack(spacing: 16) {
            if store.mode == .register {
                HStack(spacing: 12) {
                    TextField("First Name", text: $store.firstName)
                        .textContentType(.givenName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Last Name", text: $store.lastName)
                        .textContentType(.familyName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            TextField("Email", text: $store.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            if store.mode != .forgotPassword {
                SecureField("Password", text: $store.password)
                    .textContentType(store.mode == .login ? .password : .newPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if store.mode == .register {
                SecureField("Confirm Password", text: $store.confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = store.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionsView: some View {
        VStack(spacing: 16) {
            Button(action: primaryAction) {
                Group {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Text(primaryButtonTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.isFormValid)

            if store.mode == .login {
                Button("Forgot Password?") {
                    store.send(.setMode(.forgotPassword))
                }
                .font(.subheadline)
            }

            HStack {
                Text(secondaryText)
                    .foregroundStyle(.secondary)

                Button(secondaryButtonTitle) {
                    store.send(.setMode(secondaryMode))
                }
            }
            .font(.subheadline)
        }
    }

    private var primaryButtonTitle: String {
        switch store.mode {
        case .login: "Sign In"
        case .register: "Create Account"
        case .forgotPassword: "Send Reset Link"
        }
    }

    private func primaryAction() {
        switch store.mode {
        case .login:
            store.send(.loginTapped)
        case .register:
            store.send(.registerTapped)
        case .forgotPassword:
            store.send(.forgotPasswordTapped)
        }
    }

    private var secondaryText: String {
        switch store.mode {
        case .login: "Don't have an account?"
        case .register, .forgotPassword: "Already have an account?"
        }
    }

    private var secondaryButtonTitle: String {
        switch store.mode {
        case .login: "Sign Up"
        case .register, .forgotPassword: "Sign In"
        }
    }

    private var secondaryMode: AuthenticationFeature.State.Mode {
        switch store.mode {
        case .login: .register
        case .register, .forgotPassword: .login
        }
    }
}

// MARK: - Preview

#Preview("Login") {
    AuthenticationView(
        store: .init(initialState: AuthenticationFeature.State(mode: .login)) {
            AuthenticationFeature()
        }
    )
}

#Preview("Register") {
    AuthenticationView(
        store: .init(initialState: AuthenticationFeature.State(mode: .register)) {
            AuthenticationFeature()
        }
    )
}

#Preview("Forgot Password") {
    AuthenticationView(
        store: .init(initialState: AuthenticationFeature.State(mode: .forgotPassword)) {
            AuthenticationFeature()
        }
    )
}

#Preview("Login - With Email") {
    AuthenticationView(
        store: .init(
            initialState: AuthenticationFeature.State(
                mode: .login,
                email: "test@example.com"
            )
        ) {
            AuthenticationFeature()
        }
    )
}

#Preview("Login - Loading") {
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

#Preview("Login - Error") {
    AuthenticationView(
        store: .init(
            initialState: AuthenticationFeature.State(
                mode: .login,
                email: "test@example.com",
                password: "wrong",
                error: "Invalid email or password. Please try again."
            )
        ) {
            AuthenticationFeature()
        }
    )
}
