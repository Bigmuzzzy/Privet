//
//  MessageBubbleView.swift
//  Privet
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    @State private var showFullScreenImage = false

    private var bubbleColor: Color {
        message.isFromCurrentUser ? .whatsAppLightGreen : .white
    }

    private var hasMedia: Bool {
        message.mediaUrl != nil && !message.mediaUrl!.isEmpty
    }

    private var messageTime: Date {
        message.createdAt ?? Date()
    }

    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Медиа контент
                if hasMedia {
                    mediaContent
                }

                // Текст
                if let text = message.content, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                }

                // Время и статус
                HStack(spacing: 4) {
                    Text(messageTime.messageTimeString())
                        .font(.system(size: 11))
                        .foregroundColor(hasMedia && message.content == nil ? .white.opacity(0.9) : .gray)

                    if message.isFromCurrentUser {
                        statusIcon
                    }
                }
                .padding(.trailing, hasMedia && message.content == nil ? 8 : 0)
                .padding(.bottom, hasMedia && message.content == nil ? 4 : 0)
            }
            .padding(.horizontal, hasMedia ? 4 : 12)
            .padding(.vertical, hasMedia ? 4 : 8)
            .background(hasMedia && message.content == nil ? Color.clear : bubbleColor)
            .clipShape(BubbleShape(isFromCurrentUser: message.isFromCurrentUser))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                FullScreenImageView(url: url)
            }
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if message.type == .image, let urlString = message.mediaUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 250, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            showFullScreenImage = true
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if message.content == nil {
                                timeOverlay
                            }
                        }
                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
        } else if message.type == .video, let _ = message.mediaUrl {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(width: 200, height: 150)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.9))
            }
            .overlay(alignment: .bottomTrailing) {
                if message.content == nil {
                    timeOverlay
                }
            }
        }
    }

    private var timeOverlay: some View {
        HStack(spacing: 4) {
            Text(messageTime.messageTimeString())
                .font(.system(size: 11))
                .foregroundColor(.white)

            if message.isFromCurrentUser {
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(message.status == .read ? .whatsAppBlue : .white)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(message.status == .read ? .whatsAppBlue : .white)
                            .offset(x: 4)
                            .opacity(message.status == .delivered || message.status == .read ? 1 : 0)
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
        .padding(8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        case .delivered:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .offset(x: 4)
                )
        case .read:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.whatsAppBlue)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.whatsAppBlue)
                        .offset(x: 4)
                )
        }
    }
}

// MARK: - Full Screen Image View

struct FullScreenImageView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = value
                                    }
                                    .onEnded { _ in
                                        withAnimation {
                                            scale = max(1.0, min(scale, 3.0))
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    scale = scale > 1 ? 1 : 2
                                }
                            }
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct BubbleShape: Shape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromCurrentUser
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ZStack {
        Color.whatsAppChatBackground.ignoresSafeArea()

        VStack {
            MessageBubbleView(message: Message(
                chatId: "1",
                senderId: "other",
                content: "Привет! Как дела?",
                type: .text,
                status: .read,
                createdAt: Date(),
                isFromCurrentUser: false
            ))

            MessageBubbleView(message: Message(
                chatId: "1",
                senderId: "me",
                content: "Привет! Всё отлично!",
                type: .text,
                status: .read,
                createdAt: Date(),
                isFromCurrentUser: true
            ))

            MessageBubbleView(message: Message(
                chatId: "1",
                senderId: "me",
                content: nil,
                type: .image,
                mediaUrl: "https://picsum.photos/400/300",
                status: .delivered,
                createdAt: Date(),
                isFromCurrentUser: true
            ))
        }
    }
}
