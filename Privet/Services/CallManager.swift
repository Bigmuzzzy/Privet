//
//  CallManager.swift
//  Privet
//
//  WebRTC call management service
//

import Foundation
import AVFoundation
import Combine
import WebRTC

enum CallState {
    case idle
    case outgoing      // We initiated the call
    case incoming      // Receiving a call
    case ringing       // Waiting for answer
    case connecting    // Call answered, establishing connection
    case connected     // Active call
    case ended
    case failed
}

enum CallType {
    case audio
    case video

    var rawValue: String {
        switch self {
        case .audio: return "audio"
        case .video: return "video"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "audio": self = .audio
        case "video": self = .video
        default: return nil
        }
    }
}

class CallManager: NSObject, ObservableObject {
    static let shared = CallManager()

    @Published var callState: CallState = .idle
    @Published var currentCallType: CallType?
    @Published var remoteUserId: String?
    @Published var remoteUserName: String?
    @Published var chatId: String?
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = false

    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoTrack: RTCVideoTrack?
    private var localVideoSource: RTCVideoSource?
    private var videoCapturer: RTCCameraVideoCapturer?

    private var cancellables = Set<AnyCancellable>()
    private var callUUID: UUID?

    // WebRTC factory
    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()

    // ICE servers (STUN servers for NAT traversal)
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
    ]

    private override init() {
        super.init()
        setupWebSocketListeners()
    }

    deinit {
        RTCCleanupSSL()
    }

    // MARK: - WebSocket Integration

    private func setupWebSocketListeners() {
        // Listen for incoming calls
        WebSocketService.shared.incomingCallPublisher
            .sink { [weak self] (callerId, offer, callType, chatId) in
                self?.handleIncomingCall(callerId: callerId, offer: offer, callType: callType, chatId: chatId)
            }
            .store(in: &cancellables)

        // Listen for call answered
        WebSocketService.shared.callAnsweredPublisher
            .sink { [weak self] (answerId, answer) in
                self?.handleCallAnswered(answer: answer)
            }
            .store(in: &cancellables)

        // Listen for ICE candidates
        WebSocketService.shared.iceCandidatePublisher
            .sink { [weak self] (senderId, candidate) in
                self?.handleRemoteIceCandidate(candidate: candidate)
            }
            .store(in: &cancellables)

        // Listen for call ended
        WebSocketService.shared.callEndedPublisher
            .sink { [weak self] (userId, reason) in
                self?.handleCallEnded(reason: reason)
            }
            .store(in: &cancellables)

        // Listen for call rejected
        WebSocketService.shared.callRejectedPublisher
            .sink { [weak self] (userId, reason) in
                self?.handleCallRejected(reason: reason)
            }
            .store(in: &cancellables)
    }

    // MARK: - Outgoing Call

    func startCall(to userId: String, userName: String, chatId: String, type: CallType) async throws {
        guard callState == .idle else {
            throw CallError.callInProgress
        }

        self.remoteUserId = userId
        self.remoteUserName = userName
        self.chatId = chatId
        self.currentCallType = type

        // Start CallKit call
        CallKitManager.shared.startCall(to: userName, isVideo: type == .video)

        await MainActor.run {
            self.callState = .outgoing
        }

        // Setup audio session
        try configureAudioSession()

        // Create peer connection
        try setupPeerConnection()

        // Add local media tracks
        if type == .audio || type == .video {
            addAudioTrack()
        }
        if type == .video {
            try addVideoTrack()
        }

        // Create offer
        let offer = try await createOffer()

        // Send offer via WebSocket
        sendCallOffer(to: userId, offer: offer, type: type, chatId: chatId)

        // Notify CallKit that we're connecting
        CallKitManager.shared.updateCall(startedConnectingAt: Date())

        await MainActor.run {
            self.callState = .ringing
        }
    }

    // MARK: - Incoming Call

    private func handleIncomingCall(callerId: String, offer: String, callType: String, chatId: String) {
        guard callState == .idle,
              let type = CallType(rawValue: callType) else {
            // Reject if already in a call
            rejectCall(callerId: callerId, reason: "busy")
            return
        }

        self.remoteUserId = callerId
        self.chatId = chatId
        self.currentCallType = type

        // Create UUID for CallKit
        let uuid = UUID()
        self.callUUID = uuid

        // Get caller name (TODO: fetch from server if needed)
        let callerName = callerId

        // Report incoming call to CallKit
        CallKitManager.shared.reportIncomingCall(from: callerName, uuid: uuid, isVideo: type == .video) { error in
            if let error = error {
                print("Failed to report incoming call to CallKit: \(error)")
            }
        }

        Task { @MainActor in
            self.callState = .incoming
        }

        // Store offer for when user accepts
        UserDefaults.standard.set(offer, forKey: "pendingCallOffer")
    }

    func acceptCall() async throws {
        guard callState == .incoming,
              let offer = UserDefaults.standard.string(forKey: "pendingCallOffer"),
              let callerId = remoteUserId,
              let type = currentCallType else {
            throw CallError.invalidState
        }

        await MainActor.run {
            self.callState = .connecting
        }

        // Setup audio session
        try configureAudioSession()

        // Create peer connection
        try setupPeerConnection()

        // Add local media
        if type == .audio || type == .video {
            addAudioTrack()
        }
        if type == .video {
            try addVideoTrack()
        }

        // Set remote description (offer)
        try await setRemoteOffer(offer)

        // Create answer
        let answer = try await createAnswer()

        // Send answer via WebSocket
        sendCallAnswer(to: callerId, answer: answer)

        UserDefaults.standard.removeObject(forKey: "pendingCallOffer")
    }

    func rejectCall() {
        guard let callerId = remoteUserId else { return }
        rejectCall(callerId: callerId, reason: "declined")
        cleanup()
    }

    private func rejectCall(callerId: String, reason: String) {
        WebSocketService.shared.send([
            "type": "call_reject",
            "callerId": callerId,
            "reason": reason
        ])
    }

    // MARK: - Call Control

    func endCall() {
        guard let recipientId = remoteUserId else {
            cleanup()
            return
        }

        WebSocketService.shared.send([
            "type": "call_end",
            "recipientId": recipientId,
            "reason": "normal"
        ])

        // End CallKit call
        CallKitManager.shared.endCall()

        cleanup()
    }

    func toggleMute() {
        isMuted.toggle()
        localAudioTrack?.isEnabled = !isMuted
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
    }

    // MARK: - WebRTC Setup

    private func setupPeerConnection() throws {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw CallError.peerConnectionFailed
        }

        self.peerConnection = pc
    }

    private func addAudioTrack() {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstraints)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")

        peerConnection?.add(audioTrack, streamIds: ["stream0"])
        localAudioTrack = audioTrack
    }

    private func addVideoTrack() throws {
        let videoSource = factory.videoSource()
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")

        peerConnection?.add(videoTrack, streamIds: ["stream0"])

        localVideoSource = videoSource
        localVideoTrack = videoTrack

        // Setup camera capturer
        let capturer = RTCCameraVideoCapturer(delegate: videoSource)
        videoCapturer = capturer

        // Start capturing
        startCameraCapture()
    }

    private func startCameraCapture() {
        guard let capturer = videoCapturer else { return }

        guard let frontCamera = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == .front }) else {
            return
        }

        let formats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
        guard let format = formats.first(where: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width == 640
        }) ?? formats.first else {
            return
        }

        let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30

        capturer.startCapture(with: frontCamera, format: format, fps: Int(fps))
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try audioSession.setActive(true)
    }

    // MARK: - Signaling

    private func createOffer() async throws -> String {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": currentCallType == .video ? "true" : "false"
            ],
            optionalConstraints: nil
        )

        guard let pc = peerConnection else {
            throw CallError.peerConnectionFailed
        }

        let offer = try await pc.offer(for: constraints)
        try await pc.setLocalDescription(offer)

        return offer.sdp
    }

    private func createAnswer() async throws -> String {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": currentCallType == .video ? "true" : "false"
            ],
            optionalConstraints: nil
        )

        guard let pc = peerConnection else {
            throw CallError.peerConnectionFailed
        }

        let answer = try await pc.answer(for: constraints)
        try await pc.setLocalDescription(answer)

        return answer.sdp
    }

    private func setRemoteOffer(_ sdp: String) async throws {
        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        try await peerConnection?.setRemoteDescription(sessionDescription)
    }

    private func handleCallAnswered(answer: String) {
        Task {
            do {
                let sessionDescription = RTCSessionDescription(type: .answer, sdp: answer)
                try await peerConnection?.setRemoteDescription(sessionDescription)

                // Notify CallKit that call connected
                CallKitManager.shared.updateCall(connectedAt: Date())

                await MainActor.run {
                    self.callState = .connected
                }
            } catch {
                print("Failed to set remote answer: \(error)")
                CallKitManager.shared.reportCallEnded(reason: .failed)
                cleanup()
            }
        }
    }

    private func handleRemoteIceCandidate(candidate: [String: Any]) {
        guard let sdp = candidate["candidate"] as? String,
              let sdpMLineIndex = candidate["sdpMLineIndex"] as? Int32,
              let sdpMid = candidate["sdpMid"] as? String else {
            return
        }

        let iceCandidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        peerConnection?.add(iceCandidate)
    }

    private func handleCallEnded(reason: String?) {
        print("Call ended: \(reason ?? "unknown")")
        CallKitManager.shared.reportCallEnded(reason: .remoteEnded)
        cleanup()
    }

    private func handleCallRejected(reason: String?) {
        print("Call rejected: \(reason ?? "unknown")")
        CallKitManager.shared.reportCallEnded(reason: .declinedElsewhere)
        cleanup()
    }

    // MARK: - WebSocket Sending

    private func sendCallOffer(to recipientId: String, offer: String, type: CallType, chatId: String) {
        WebSocketService.shared.send([
            "type": "call_offer",
            "recipientId": recipientId,
            "offer": offer,
            "callType": type.rawValue,
            "chatId": chatId
        ])
    }

    private func sendCallAnswer(to callerId: String, answer: String) {
        WebSocketService.shared.send([
            "type": "call_answer",
            "callerId": callerId,
            "answer": answer
        ])
    }

    private func sendIceCandidate(_ candidate: RTCIceCandidate, to recipientId: String) {
        WebSocketService.shared.send([
            "type": "ice_candidate",
            "recipientId": recipientId,
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid ?? ""
            ]
        ])
    }

    // MARK: - Cleanup

    private func cleanup() {
        Task { @MainActor in
            self.callState = .ended
        }

        localAudioTrack?.isEnabled = false
        localVideoTrack?.isEnabled = false
        videoCapturer?.stopCapture()

        peerConnection?.close()
        peerConnection = nil

        localAudioTrack = nil
        localVideoTrack = nil
        localVideoSource = nil
        videoCapturer = nil

        remoteUserId = nil
        remoteUserName = nil
        chatId = nil
        currentCallType = nil
        callUUID = nil
        isMuted = false
        isSpeakerOn = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        Task { @MainActor in
            self.callState = .idle
        }
    }
}

// MARK: - RTCPeerConnectionDelegate

extension CallManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Stream added with \(stream.audioTracks.count) audio tracks and \(stream.videoTracks.count) video tracks")

        if callState == .connecting {
            Task { @MainActor in
                self.callState = .connected
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("Stream removed")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Peer connection should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE connection state changed: \(newState)")

        switch newState {
        case .connected:
            Task { @MainActor in
                if self.callState != .connected {
                    self.callState = .connected
                }
            }
        case .failed, .disconnected:
            cleanup()
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed: \(newState)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("Generated ICE candidate")

        if let recipientId = remoteUserId {
            sendIceCandidate(candidate, to: recipientId)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("Removed ICE candidates")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
    }
}

// MARK: - Errors

enum CallError: LocalizedError {
    case callInProgress
    case invalidState
    case peerConnectionFailed
    case noMedia

    var errorDescription: String? {
        switch self {
        case .callInProgress:
            return "A call is already in progress"
        case .invalidState:
            return "Invalid call state"
        case .peerConnectionFailed:
            return "Failed to create peer connection"
        case .noMedia:
            return "Failed to access camera or microphone"
        }
    }
}
