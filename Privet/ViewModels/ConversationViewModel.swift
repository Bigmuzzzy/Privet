//
//  ConversationViewModel.swift
//  Privet
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var isSendingImage: Bool = false
    @Published var chat: Chat

    private let chatService = ChatService.shared
    private let authService = AuthService.shared
    private let mediaService = MediaService.shared
    private var cancellables = Set<AnyCancellable>()

    var currentUserId: String {
        authService.currentUser?.id ?? ""
    }

    init(chat: Chat) {
        self.chat = chat
        setupBindings()
        loadMessages()
    }

    private func setupBindings() {
        chatService.$currentMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.messages = messages
            }
            .store(in: &cancellables)

        mediaService.$isUploading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isUploading in
                self?.isSendingImage = isUploading
            }
            .store(in: &cancellables)

        // Listen for online status updates
        WebSocketService.shared.onlineStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (userId, isOnline, lastSeen) in
                guard let self = self, self.chat.otherUser?.id == userId else { return }
                self.chat.otherUser?.isOnline = isOnline
                self.chat.otherUser?.lastSeen = lastSeen
            }
            .store(in: &cancellables)
    }

    func loadMessages() {
        isLoading = true

        Task {
            do {
                try await chatService.loadMessages(chatId: chat.id)
                await chatService.markAsRead(chatId: chat.id)
            } catch {
                print("Failed to load messages: \(error)")
            }
            isLoading = false
        }
    }

    func stopListening() {
        chatService.clearCurrentMessages()
    }

    func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let textToSend = text
        messageText = ""

        Task {
            do {
                _ = try await chatService.sendMessage(chatId: chat.id, text: textToSend)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }

    func sendImage(_ image: UIImage) {
        let compressedImage = mediaService.compressImage(image)
        isSendingImage = true

        Task {
            do {
                try await chatService.sendImageMessage(chatId: chat.id, image: compressedImage)
            } catch {
                print("Failed to send image: \(error)")
            }
            isSendingImage = false
        }
    }

    func refresh() async {
        do {
            try await chatService.loadMessages(chatId: chat.id)
        } catch {
            print("Failed to refresh messages: \(error)")
        }
    }
}
