//
//  WebSocketService.swift
//  Privet
//

import Foundation
import Combine

class WebSocketService: ObservableObject {
    static let shared = WebSocketService()

    @Published var isConnected: Bool = false

    // Publishers for different event types
    let newMessagePublisher = PassthroughSubject<Message, Never>()
    let messageStatusPublisher = PassthroughSubject<(messageId: String, chatId: String, status: MessageStatus), Never>()
    let typingPublisher = PassthroughSubject<(chatId: String, userId: String, isTyping: Bool), Never>()
    let onlineStatusPublisher = PassthroughSubject<(userId: String, isOnline: Bool, lastSeen: Date?), Never>()
    let messageDeletedPublisher = PassthroughSubject<String, Never>()

    // WebRTC Call Publishers
    // TODO: Uncomment when WebRTC is properly configured
    /*
    let incomingCallPublisher = PassthroughSubject<(callerId: String, offer: String, callType: String, chatId: String), Never>()
    let callAnsweredPublisher = PassthroughSubject<(answerId: String, answer: String), Never>()
    let iceCandidatePublisher = PassthroughSubject<(senderId: String, candidate: [String: Any]), Never>()
    let callEndedPublisher = PassthroughSubject<(userId: String, reason: String?), Never>()
    let callRejectedPublisher = PassthroughSubject<(userId: String, reason: String?), Never>()
    */

    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    private init() {}

    func connect() {
        guard let url = APIClient.shared.getWebSocketURL() else {
            print("WebSocket: No auth token available")
            return
        }

        disconnect()

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()
        startPingTimer()

        reconnectAttempts = 0
        print("WebSocket: Connecting...")
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        Task { @MainActor in
            self.isConnected = false
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self?.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "connected":
            print("WebSocket: Connected")
            Task { @MainActor in
                self.isConnected = true
            }

        case "pong":
            // Heartbeat response
            break

        case "new_message":
            if let messageData = try? JSONSerialization.data(withJSONObject: json["message"] as Any),
               let message = try? JSONDecoder.apiDecoder.decode(Message.self, from: messageData) {
                newMessagePublisher.send(message)
            }

        case "message_status":
            if let messageId = json["messageId"] as? String,
               let chatId = json["chatId"] as? String,
               let statusStr = json["status"] as? String,
               let status = MessageStatus(rawValue: statusStr) {
                messageStatusPublisher.send((messageId, chatId, status))
            }

        case "typing":
            if let chatId = json["chatId"] as? String,
               let userId = json["userId"] as? String,
               let isTyping = json["isTyping"] as? Bool {
                typingPublisher.send((chatId, userId, isTyping))
            }

        case "user_online_status":
            if let userId = json["userId"] as? String,
               let isOnline = json["isOnline"] as? Bool {
                let lastSeen: Date?
                if let lastSeenStr = json["lastSeen"] as? String {
                    lastSeen = ISO8601DateFormatter().date(from: lastSeenStr)
                } else {
                    lastSeen = nil
                }
                onlineStatusPublisher.send((userId, isOnline, lastSeen))
            }

        case "message_deleted":
            if let messageId = json["messageId"] as? String {
                messageDeletedPublisher.send(messageId)
            }

        case "messages_read":
            if let chatId = json["chatId"] as? String,
               let messageIds = json["messageIds"] as? [String] {
                for messageId in messageIds {
                    messageStatusPublisher.send((messageId, chatId, .read))
                }
            }

        // WebRTC Call Events
        // TODO: Uncomment when WebRTC is properly configured
        /*
        case "incoming_call":
            if let callerId = json["callerId"] as? String,
               let offer = json["offer"] as? String,
               let callType = json["callType"] as? String,
               let chatId = json["chatId"] as? String {
                incomingCallPublisher.send((callerId, offer, callType, chatId))
            }

        case "call_answered":
            if let answerId = json["answerId"] as? String,
               let answer = json["answer"] as? String {
                callAnsweredPublisher.send((answerId, answer))
            }

        case "ice_candidate":
            if let senderId = json["senderId"] as? String,
               let candidate = json["candidate"] as? [String: Any] {
                iceCandidatePublisher.send((senderId, candidate))
            }

        case "call_ended":
            if let userId = json["userId"] as? String {
                let reason = json["reason"] as? String
                callEndedPublisher.send((userId, reason))
            }

        case "call_rejected":
            if let userId = json["userId"] as? String {
                let reason = json["reason"] as? String
                callRejectedPublisher.send((userId, reason))
            }
        */

        default:
            print("WebSocket: Unknown message type: \(type)")
        }
    }

    private func handleDisconnect() {
        Task { @MainActor in
            self.isConnected = false
        }

        // Try to reconnect
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = Double(reconnectAttempts) * 2.0
            print("WebSocket: Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.connect()
            }
        }
    }

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        send(["type": "ping"])
    }

    func sendTyping(chatId: String, isTyping: Bool) {
        send([
            "type": "typing",
            "chatId": chatId,
            "isTyping": isTyping
        ])
    }

    func sendReadReceipts(messageIds: [String]) {
        send([
            "type": "message_read",
            "messageIds": messageIds
        ])
    }

    // Public send method for other services (like CallManager)
    func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
