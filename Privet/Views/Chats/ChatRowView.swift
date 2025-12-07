//
//  ChatRowView.swift
//  Privet
//

import SwiftUI

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                name: chat.displayName,
                size: 56,
                imageURL: chat.displayAvatarUrl,
                isOnline: chat.isRecipientOnline
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let date = chat.lastMessage?.createdAt {
                        Text(date.chatTimeString())
                            .font(.system(size: 13))
                            .foregroundColor(chat.unreadCount > 0 ? .whatsAppGreen : .secondary)
                    }
                }

                HStack {
                    Text(lastMessageText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Spacer()

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.whatsAppGreen)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var lastMessageText: String {
        guard let lastMessage = chat.lastMessage else {
            return "Нет сообщений"
        }

        switch lastMessage.type {
        case "image":
            return "📷 Фото"
        case "video":
            return "🎥 Видео"
        case "voice":
            return "🎤 Голосовое сообщение"
        default:
            return lastMessage.content ?? "Нет сообщений"
        }
    }
}

#Preview {
    List {
        ChatRowView(chat: Chat(
            otherUser: ChatUser(id: "1", displayName: "Алексей", isOnline: true),
            lastMessage: ChatLastMessage(id: "1", content: "Привет! Как дела?", type: "text", senderId: "1", createdAt: Date()),
            unreadCount: 2
        ))

        ChatRowView(chat: Chat(
            otherUser: ChatUser(id: "2", displayName: "Мария", isOnline: false, lastSeen: Date().addingTimeInterval(-3600)),
            lastMessage: ChatLastMessage(id: "2", content: "Увидимся завтра в 10:00", type: "text", senderId: "2", createdAt: Date().addingTimeInterval(-3600)),
            unreadCount: 0
        ))
    }
    .listStyle(.plain)
}
