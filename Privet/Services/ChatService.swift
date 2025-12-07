//
//  ChatService.swift
//  Privet
//

import Foundation
import Combine
import UIKit

class ChatService: ObservableObject {
    static let shared = ChatService()

    @Published var chats: [Chat] = []
    @Published var currentMessages: [Message] = []
    @Published var availableUsers: [User] = []

    private let api = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupWebSocketListeners()
    }

    private func setupWebSocketListeners() {
        // Listen for new messages to update chat list
        WebSocketService.shared.newMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleNewMessage(message)
            }
            .store(in: &cancellables)

        // Listen for online status changes
        WebSocketService.shared.onlineStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (userId, isOnline, lastSeen) in
                self?.updateUserOnlineStatus(userId: userId, isOnline: isOnline, lastSeen: lastSeen)
            }
            .store(in: &cancellables)

        // Listen for message status updates
        WebSocketService.shared.messageStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (messageId, _, status) in
                self?.updateMessageStatus(messageId: messageId, status: status)
            }
            .store(in: &cancellables)

        // Listen for message deletions
        WebSocketService.shared.messageDeletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messageId in
                self?.currentMessages.removeAll { $0.id == messageId }
            }
            .store(in: &cancellables)
    }

    // MARK: - Chats

    func loadChats() async throws {
        let chats: [Chat] = try await api.get("/api/chats")

        await MainActor.run {
            self.chats = chats
        }
    }

    func getOrCreatePrivateChat(with userId: String) async throws -> Chat {
        let chat: Chat = try await api.post("/api/chats/private", body: [
            "userId": userId
        ])

        // Add to list if not present
        await MainActor.run {
            if !self.chats.contains(where: { $0.id == chat.id }) {
                self.chats.insert(chat, at: 0)
            }
        }

        return chat
    }

    func deleteChat(_ chatId: String) async throws {
        try await api.delete("/api/chats/\(chatId)")

        await MainActor.run {
            self.chats.removeAll { $0.id == chatId }
        }
    }

    // MARK: - Messages

    func loadMessages(chatId: String, before: Date? = nil) async throws {
        var endpoint = "/api/messages/chat/\(chatId)?limit=50"
        if let before = before {
            endpoint += "&before=\(ISO8601DateFormatter().string(from: before))"
        }

        let messages: [Message] = try await api.get(endpoint)

        // Mark messages with isFromCurrentUser
        let currentUserId = AuthService.shared.currentUser?.id
        let updatedMessages = messages.map { msg -> Message in
            var m = msg
            m.isFromCurrentUser = msg.senderId == currentUserId
            return m
        }

        await MainActor.run {
            if before != nil {
                // Prepend older messages
                self.currentMessages = updatedMessages + self.currentMessages
            } else {
                self.currentMessages = updatedMessages
            }
        }
    }

    func sendMessage(chatId: String, text: String, type: MessageType = .text, mediaUrl: String? = nil) async throws -> Message {
        var body: [String: Any] = [
            "chatId": chatId,
            "type": type.rawValue
        ]

        if let text = text.isEmpty ? nil : text {
            body["content"] = text
        }

        if let mediaUrl = mediaUrl {
            body["mediaUrl"] = mediaUrl
        }

        let message: Message = try await api.post("/api/messages", body: body)

        // Add to current messages
        await MainActor.run {
            var msg = message
            msg.isFromCurrentUser = true
            self.currentMessages.append(msg)
            self.updateChatLastMessage(message)
        }

        return message
    }

    func sendImageMessage(chatId: String, image: UIImage) async throws {
        let messageId = UUID().uuidString

        // Upload image
        let imageURL = try await MediaService.shared.uploadImage(image, chatId: chatId, messageId: messageId)

        // Send message with image URL
        _ = try await sendMessage(chatId: chatId, text: "", type: .image, mediaUrl: imageURL)
    }

    func markAsRead(chatId: String) async {
        do {
            let _: SuccessResponse = try await api.post("/api/chats/\(chatId)/read")

            await MainActor.run {
                if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                    self.chats[index].unreadCount = 0
                }
            }

            // Send read receipts via WebSocket
            let unreadMessageIds = currentMessages
                .filter { !$0.isFromCurrentUser && $0.status != .read }
                .map { $0.id }

            if !unreadMessageIds.isEmpty {
                WebSocketService.shared.sendReadReceipts(messageIds: unreadMessageIds)
            }
        } catch {
            print("Failed to mark chat as read: \(error)")
        }
    }

    func clearCurrentMessages() {
        currentMessages = []
    }

    // MARK: - Users

    func searchUsers(username: String) async throws -> [User] {
        return try await api.get("/api/users/search/username?username=\(username)")
    }

    func fetchAvailableUsers() async {
        // For now, this is not needed since we search by username
        // Could implement contact list from server if needed
    }

    // MARK: - Search

    func searchChats(query: String) -> [Chat] {
        guard !query.isEmpty else { return chats }
        return chats.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            ($0.lastMessage?.content?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Typing Indicator

    func sendTypingIndicator(chatId: String, isTyping: Bool) {
        WebSocketService.shared.sendTyping(chatId: chatId, isTyping: isTyping)
    }

    // MARK: - Private Methods

    private func handleNewMessage(_ message: Message) {
        let currentUserId = AuthService.shared.currentUser?.id

        // Add to current messages if we're viewing this chat
        if !currentMessages.isEmpty && currentMessages.first?.chatId == message.chatId {
            var msg = message
            msg.isFromCurrentUser = message.senderId == currentUserId
            currentMessages.append(msg)
        }

        // Update chat list
        updateChatLastMessage(message)
    }

    private func updateChatLastMessage(_ message: Message) {
        let currentUserId = AuthService.shared.currentUser?.id

        if let index = chats.firstIndex(where: { $0.id == message.chatId }) {
            var chat = chats[index]

            chat.lastMessage = ChatLastMessage(
                id: message.id,
                content: message.content,
                type: message.type.rawValue,
                senderId: message.senderId,
                createdAt: message.createdAt
            )

            // Increment unread if not from current user
            if message.senderId != currentUserId {
                chat.unreadCount += 1
            }

            // Move to top
            chats.remove(at: index)
            chats.insert(chat, at: 0)
        } else {
            // New chat - reload all chats
            Task {
                try? await loadChats()
            }
        }
    }

    private func updateUserOnlineStatus(userId: String, isOnline: Bool, lastSeen: Date?) {
        for i in chats.indices {
            if chats[i].otherUser?.id == userId {
                chats[i].otherUser?.isOnline = isOnline
                chats[i].otherUser?.lastSeen = lastSeen
            }
        }
    }

    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
            currentMessages[index].status = status
        }
    }
}
