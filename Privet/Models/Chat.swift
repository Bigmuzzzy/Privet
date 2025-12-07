//
//  Chat.swift
//  Privet
//

import Foundation

struct Chat: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    var name: String?
    var avatarUrl: String?
    var otherUser: ChatUser?
    var lastMessage: ChatLastMessage?
    var unreadCount: Int
    var createdAt: Date?
    var updatedAt: Date?

    // Computed properties for convenience
    var displayName: String {
        if type == "private", let user = otherUser {
            return user.displayName
        }
        return name ?? "Chat"
    }

    var displayAvatarUrl: String? {
        if type == "private", let user = otherUser {
            return user.avatarUrl
        }
        return avatarUrl
    }

    var isRecipientOnline: Bool {
        return otherUser?.isOnline ?? false
    }

    var recipientLastSeen: Date? {
        return otherUser?.lastSeen
    }

    init(
        id: String = UUID().uuidString,
        type: String = "private",
        name: String? = nil,
        avatarUrl: String? = nil,
        otherUser: ChatUser? = nil,
        lastMessage: ChatLastMessage? = nil,
        unreadCount: Int = 0,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.avatarUrl = avatarUrl
        self.otherUser = otherUser
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ChatUser: Codable, Hashable {
    let id: String
    var username: String?
    var displayName: String
    var avatarUrl: String?
    var isOnline: Bool?
    var lastSeen: Date?
}

struct ChatLastMessage: Codable, Hashable {
    let id: String
    var content: String?
    var type: String
    var senderId: String
    var createdAt: Date?
}
