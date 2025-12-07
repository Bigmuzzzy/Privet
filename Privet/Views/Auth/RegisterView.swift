//
//  RegisterView.swift
//  Privet
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя часть
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.whatsAppGreen)

                Text("Регистрация")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Создайте новый аккаунт")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(maxHeight: .infinity)

            // Форма регистрации
            VStack(spacing: 16) {
                TextField("Имя пользователя", text: $viewModel.username)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.username)
                    .autocapitalization(.none)

                TextField("Имя", text: $viewModel.displayName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.name)

                SecureField("Пароль", text: $viewModel.password)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)

                SecureField("Подтвердите пароль", text: $viewModel.confirmPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)

                // Подсказки
                VStack(alignment: .leading, spacing: 4) {
                    HintRow(text: "Минимум 3 символа в имени пользователя", isValid: viewModel.username.count >= 3)
                    HintRow(text: "Минимум 2 символа в имени", isValid: viewModel.displayName.count >= 2)
                    HintRow(text: "Минимум 6 символов в пароле", isValid: viewModel.password.count >= 6)
                    HintRow(text: "Пароли совпадают", isValid: !viewModel.confirmPassword.isEmpty && viewModel.password == viewModel.confirmPassword)
                }
                .padding(.horizontal, 4)

                Button(action: {
                    Task {
                        await viewModel.register()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Зарегистрироваться")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.isRegisterValid ? Color.whatsAppGreen : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                .disabled(!viewModel.isRegisterValid || viewModel.isLoading)

                Button(action: {
                    dismiss()
                }) {
                    Text("Уже есть аккаунт? ")
                        .foregroundColor(.secondary)
                    + Text("Войти")
                        .foregroundColor(.whatsAppGreen)
                        .fontWeight(.semibold)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.whatsAppGreen)
                }
            }
        }
        .alert("Ошибка", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Неизвестная ошибка")
        }
    }
}

struct HintRow: View {
    let text: String
    let isValid: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .whatsAppGreen : .gray)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .primary : .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
}
