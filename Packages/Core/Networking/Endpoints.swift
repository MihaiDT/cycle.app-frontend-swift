import Foundation

// MARK: - Auth Endpoints

public enum AuthEndpoints {
    public static func login(email: String, password: String) -> Endpoint {
        .post("/auth/login", body: LoginRequest(email: email, password: password))
    }

    public static func register(email: String, password: String, firstName: String?, lastName: String?) -> Endpoint {
        .post("/auth/register", body: RegisterRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        ))
    }

    public static func refreshToken(_ refreshToken: String) -> Endpoint {
        .post("/auth/refresh", body: RefreshTokenRequest(refreshToken: refreshToken))
    }

    public static func logout() -> Endpoint {
        .post("/auth/logout", body: EmptyBody())
    }

    public static func forgotPassword(email: String) -> Endpoint {
        .post("/auth/forgot-password", body: ForgotPasswordRequest(email: email))
    }

    public static func resetPassword(token: String, password: String) -> Endpoint {
        .post("/auth/reset-password", body: ResetPasswordRequest(token: token, password: password))
    }
}

// MARK: - Request Bodies

private struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

private struct RegisterRequest: Encodable, Sendable {
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
}

private struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
}

private struct ForgotPasswordRequest: Encodable, Sendable {
    let email: String
}

private struct ResetPasswordRequest: Encodable, Sendable {
    let token: String
    let password: String
}

private struct EmptyBody: Encodable, Sendable {}

// MARK: - User Endpoints

public enum UserEndpoints {
    public static func me() -> Endpoint {
        .get("/users/me")
    }

    public static func update(firstName: String?, lastName: String?) -> Endpoint {
        .patch("/users/me", body: UpdateUserRequest(firstName: firstName, lastName: lastName))
    }

    public static func uploadAvatar() -> Endpoint {
        Endpoint(path: "/users/me/avatar", method: .post)
    }

    public static func deleteAccount() -> Endpoint {
        .delete("/users/me")
    }
}

private struct UpdateUserRequest: Encodable, Sendable {
    let firstName: String?
    let lastName: String?
}
