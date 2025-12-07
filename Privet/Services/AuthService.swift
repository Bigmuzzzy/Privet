//
//  AuthService.swift
//  Privet
//

import Foundation
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false

    private let api = APIClient.shared

    private init() {
        // Check if we have a saved token and try to restore session
        if api.getToken() != nil {
            Task {
                await restoreSession()
            }
        }
    }

    private func restoreSession() async {
        do {
            let user: User = try await api.get("/api/auth/me")
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            // Connect WebSocket after session restore
            WebSocketService.shared.connect()
        } catch {
            // Token invalid, clear it
            api.clearToken()
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }

    func login(username: String, password: String) async throws -> User {
        guard !username.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }

        let response: AuthResponse = try await api.post("/api/auth/login", body: [
            "username": username,
            "password": password
        ])

        api.setToken(response.token)

        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }

        // Connect WebSocket after login
        WebSocketService.shared.connect()

        return response.user
    }

    func register(username: String, password: String, displayName: String) async throws -> User {
        guard username.count >= 3 else {
            throw AuthError.usernameTooShort
        }

        guard displayName.count >= 2 else {
            throw AuthError.displayNameTooShort
        }

        guard password.count >= 6 else {
            throw AuthError.passwordTooShort
        }

        let response: AuthResponse = try await api.post("/api/auth/register", body: [
            "username": username,
            "password": password,
            "displayName": displayName
        ])

        api.setToken(response.token)

        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }

        // Connect WebSocket after registration
        WebSocketService.shared.connect()

        return response.user
    }

    func logout() {
        Task {
            // Notify server
            do {
                let _: SuccessResponse = try await api.post("/api/auth/logout")
            } catch {
                print("Logout error: \(error)")
            }
        }

        // Disconnect WebSocket
        WebSocketService.shared.disconnect()

        // Clear local state
        api.clearToken()

        Task { @MainActor in
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func updateProfile(displayName: String? = nil, avatarUrl: String? = nil, statusText: String? = nil) async throws -> User {
        var body: [String: Any] = [:]
        if let displayName = displayName { body["displayName"] = displayName }
        if let avatarUrl = avatarUrl { body["avatarUrl"] = avatarUrl }
        if let statusText = statusText { body["statusText"] = statusText }

        let user: User = try await api.patch("/api/users/me", body: body)

        await MainActor.run {
            self.currentUser = user
        }

        return user
    }

    func updateDeviceToken(_ token: String) async {
        do {
            let _: SuccessResponse = try await api.post("/api/users/device-token", body: [
                "deviceToken": token
            ])
        } catch {
            print("Failed to update device token: \(error)")
        }
    }
}

struct SuccessResponse: Decodable {
    let success: Bool
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case usernameTooShort
    case displayNameTooShort
    case passwordTooShort
    case usernameAlreadyExists
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверное имя пользователя или пароль"
        case .usernameTooShort:
            return "Имя пользователя должно быть не менее 3 символов"
        case .displayNameTooShort:
            return "Имя должно быть не менее 2 символов"
        case .passwordTooShort:
            return "Пароль должен быть не менее 6 символов"
        case .usernameAlreadyExists:
            return "Это имя пользователя уже занято"
        case .networkError:
            return "Ошибка сети. Попробуйте позже"
        }
    }
}
