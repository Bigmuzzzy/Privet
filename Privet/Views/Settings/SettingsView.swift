//
//  SettingsView.swift
//  Privet
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Профиль
                Section {
                    HStack(spacing: 16) {
                        AvatarView(
                            name: authService.currentUser?.displayName ?? "User",
                            size: 70,
                            imageURL: authService.currentUser?.avatarUrl,
                            isOnline: true
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentUser?.displayName ?? "Пользователь")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(authService.currentUser?.statusText ?? "в сети")
                                .font(.subheadline)
                                .foregroundColor(.whatsAppGreen)

                            if let username = authService.currentUser?.username {
                                Text("@\(username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "qrcode")
                            .font(.system(size: 24))
                            .foregroundColor(.whatsAppGreen)
                    }
                    .padding(.vertical, 8)
                }

                // Настройки
                Section {
                    SettingsRow(icon: "key.fill", iconColor: .gray, title: "Аккаунт")
                    SettingsRow(icon: "lock.fill", iconColor: .blue, title: "Конфиденциальность")
                    SettingsRow(icon: "message.fill", iconColor: .green, title: "Чаты")
                    SettingsRow(icon: "bell.fill", iconColor: .red, title: "Уведомления")
                    SettingsRow(icon: "circle.righthalf.filled", iconColor: .purple, title: "Оформление")
                }

                // Справка
                Section {
                    SettingsRow(icon: "questionmark.circle.fill", iconColor: .blue, title: "Помощь")
                    SettingsRow(icon: "heart.fill", iconColor: .red, title: "Пригласить друга")
                }

                // Выход
                Section {
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Выйти")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .alert("Выход", isPresented: $showLogoutAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Выйти", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Вы уверены, что хотите выйти из аккаунта?")
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(iconColor)
                .cornerRadius(6)

            Text(title)
                .font(.body)
        }
    }
}

#Preview {
    SettingsView()
}
