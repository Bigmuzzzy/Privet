//
//  User.swift
//  Privet
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var avatarUrl: String?
    var statusText: String?
    var isOnline: Bool?
    var lastSeen: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case avatarUrl
        case statusText
        case isOnline
        case lastSeen
        case createdAt
    }

    init(
        id: String = UUID().uuidString,
        username: String = "",
        displayName: String,
        avatarUrl: String? = nil,
        statusText: String? = nil,
        isOnline: Bool? = nil,
        lastSeen: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.statusText = statusText
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }
}

// Response from auth endpoints
struct AuthResponse: Decodable {
    let user: User
    let token: String
}
