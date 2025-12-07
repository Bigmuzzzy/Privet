//
//  AuthViewModel.swift
//  Privet
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var displayName: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    private let authService = AuthService.shared

    var isLoginValid: Bool {
        !username.isEmpty && !password.isEmpty
    }

    var isRegisterValid: Bool {
        username.count >= 3 && displayName.count >= 2 && password.count >= 6 && password == confirmPassword
    }

    func login() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await authService.login(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func register() async {
        guard password == confirmPassword else {
            errorMessage = "Пароли не совпадают"
            showError = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await authService.register(username: username, password: password, displayName: displayName)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func clearFields() {
        username = ""
        displayName = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
}
