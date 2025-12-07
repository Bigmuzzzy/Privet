//
//  Message.swift
//  Privet
//

import Foundation

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
}

enum MessageType: String, Codable {
    case text
    case image
    case video
    case voice
}

struct Message: Identifiable, Codable, Hashable {
    let id: String
    let chatId: String
    let senderId: String
    var content: String?
    var type: MessageType
    var mediaUrl: String?
    var mediaThumbnailUrl: String?
    var status: MessageStatus
    var replyToId: String?
    var sender: MessageSender?
    var createdAt: Date?

    var isFromCurrentUser: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, chatId, senderId, content, type, mediaUrl, mediaThumbnailUrl, status, replyToId, sender, createdAt
    }

    init(
        id: String = UUID().uuidString,
        chatId: String,
        senderId: String,
        content: String? = nil,
        type: MessageType = .text,
        mediaUrl: String? = nil,
        mediaThumbnailUrl: String? = nil,
        status: MessageStatus = .sending,
        replyToId: String? = nil,
        sender: MessageSender? = nil,
        createdAt: Date? = Date(),
        isFromCurrentUser: Bool = false
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.content = content
        self.type = type
        self.mediaUrl = mediaUrl
        self.mediaThumbnailUrl = mediaThumbnailUrl
        self.status = status
        self.replyToId = replyToId
        self.sender = sender
        self.createdAt = createdAt
        self.isFromCurrentUser = isFromCurrentUser
    }
}

struct MessageSender: Codable, Hashable {
    let id: String
    var displayName: String
    var avatarUrl: String?
}
