//
//  ConversationView.swift
//  Privet
//

import SwiftUI

struct ConversationView: View {
    @StateObject private var viewModel: ConversationViewModel
    @Environment(\.dismiss) private var dismiss

    init(chat: Chat) {
        _viewModel = StateObject(wrappedValue: ConversationViewModel(chat: chat))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Сообщения
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.whatsAppChatBackground)
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
            }

            // Индикатор загрузки изображения
            if viewModel.isSendingImage {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Отправка фото...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
            }

            // Поле ввода
            MessageInputView(text: $viewModel.messageText, onSend: {
                viewModel.sendMessage()
            }, onImageSelected: { image in
                viewModel.sendImage(image)
            })
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            viewModel.stopListening()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 8) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.whatsAppGreen)
                    }

                    AvatarView(
                        name: viewModel.chat.displayName,
                        size: 36,
                        imageURL: viewModel.chat.displayAvatarUrl,
                        isOnline: viewModel.chat.isRecipientOnline
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.chat.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(onlineStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(viewModel.chat.isRecipientOnline ? .whatsAppGreen : .secondary)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        startVideoCall()
                    }) {
                        Image(systemName: "video.fill")
                            .foregroundColor(.whatsAppGreen)
                    }

                    Button(action: {
                        startAudioCall()
                    }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.whatsAppGreen)
                    }
                }
            }
        }
    }

    private var onlineStatusText: String {
        if viewModel.chat.isRecipientOnline {
            return "в сети"
        } else if let lastSeen = viewModel.chat.recipientLastSeen {
            return lastSeen.lastSeenString()
        } else {
            return "был(а) недавно"
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func startAudioCall() {
        guard let recipientId = viewModel.chat.otherUser?.id,
              let recipientName = viewModel.chat.otherUser?.displayName,
              let chatId = viewModel.chat.id else {
            return
        }

        Task {
            do {
                try await CallManager.shared.startCall(
                    to: recipientId,
                    userName: recipientName,
                    chatId: chatId,
                    type: .audio
                )
            } catch {
                print("Failed to start audio call: \(error)")
            }
        }
    }

    private func startVideoCall() {
        guard let recipientId = viewModel.chat.otherUser?.id,
              let recipientName = viewModel.chat.otherUser?.displayName,
              let chatId = viewModel.chat.id else {
            return
        }

        Task {
            do {
                try await CallManager.shared.startCall(
                    to: recipientId,
                    userName: recipientName,
                    chatId: chatId,
                    type: .video
                )
            } catch {
                print("Failed to start video call: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(
            otherUser: ChatUser(id: "1", displayName: "Алексей", isOnline: true),
            lastMessage: ChatLastMessage(id: "1", content: "Привет!", type: "text", senderId: "1", createdAt: Date())
        ))
    }
}
