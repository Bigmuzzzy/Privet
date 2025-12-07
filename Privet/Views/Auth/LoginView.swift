//
//  LoginView.swift
//  Privet
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Верхняя часть с логотипом
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "message.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.whatsAppGreen)

                    Text("Привет")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Войдите в свой аккаунт")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxHeight: .infinity)

                // Форма входа
                VStack(spacing: 16) {
                    TextField("Имя пользователя", text: $viewModel.username)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.username)
                        .autocapitalization(.none)

                    SecureField("Пароль", text: $viewModel.password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.password)

                    Button(action: {
                        Task {
                            await viewModel.login()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Войти")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(viewModel.isLoginValid ? Color.whatsAppGreen : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                    .disabled(!viewModel.isLoginValid || viewModel.isLoading)

                    Button(action: {
                        showRegister = true
                    }) {
                        Text("Нет аккаунта? ")
                            .foregroundColor(.secondary)
                        + Text("Зарегистрироваться")
                            .foregroundColor(.whatsAppGreen)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Неизвестная ошибка")
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

#Preview {
    LoginView()
}
