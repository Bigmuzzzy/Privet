//
//  PushNotificationService.swift
//  Privet
//

import Foundation
import UserNotifications
import UIKit
import Combine

class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var deviceToken: String?
    @Published var isRegistered: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Request Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("Push permission: \(granted ? "granted" : "denied")")

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return granted
        } catch {
            print("Push permission error: \(error)")
            return false
        }
    }

    // MARK: - Handle Device Token

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device token: \(token)")

        Task { @MainActor in
            self.deviceToken = token
        }

        // Register with server if authenticated
        Task {
            await AuthService.shared.updateDeviceToken(token)
            await MainActor.run {
                self.isRegistered = true
            }
        }
    }

    func handleRegistrationError(_ error: Error) {
        print("Push registration failed: \(error)")
    }

    // MARK: - Clear Badge

    func clearBadge() {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                print("Failed to clear badge: \(error)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap - navigate to chat
        if let chatId = userInfo["chatId"] as? String {
            print("User tapped notification for chat: \(chatId)")
            NotificationCenter.default.post(
                name: .openChat,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openChat = Notification.Name("openChat")
}
