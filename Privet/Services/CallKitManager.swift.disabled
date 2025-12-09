//
//  CallKitManager.swift
//  Privet
//
//  CallKit integration for native iOS call experience
//

import Foundation
import CallKit
import AVFoundation

class CallKitManager: NSObject {
    static let shared = CallKitManager()

    private let callController = CXCallController()
    private let provider: CXProvider

    private var currentCallUUID: UUID?

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.iconTemplateImageData = UIImage(systemName: "phone.fill")?.pngData()

        provider = CXProvider(configuration: config)

        super.init()

        provider.setDelegate(self, queue: nil)
    }

    // MARK: - Outgoing Call

    func startCall(to userName: String, isVideo: Bool = false) {
        let uuid = UUID()
        currentCallUUID = uuid

        let handle = CXHandle(type: .generic, value: userName)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = isVideo

        let transaction = CXTransaction(action: startCallAction)

        callController.request(transaction) { error in
            if let error = error {
                print("CallKit: Error starting call: \(error)")
            } else {
                print("CallKit: Call started successfully")
            }
        }
    }

    // MARK: - Incoming Call

    func reportIncomingCall(from userName: String, uuid: UUID, isVideo: Bool = false, completion: @escaping (Error?) -> Void) {
        currentCallUUID = uuid

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: userName)
        update.hasVideo = isVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("CallKit: Error reporting incoming call: \(error)")
            }
            completion(error)
        }
    }

    // MARK: - End Call

    func endCall() {
        guard let uuid = currentCallUUID else { return }

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callController.request(transaction) { error in
            if let error = error {
                print("CallKit: Error ending call: \(error)")
            } else {
                print("CallKit: Call ended")
                self.currentCallUUID = nil
            }
        }
    }

    func reportCallEnded(reason: CXCallEndedReason) {
        guard let uuid = currentCallUUID else { return }
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        currentCallUUID = nil
    }

    // MARK: - Call Updates

    func updateCall(connectedAt: Date) {
        guard let uuid = currentCallUUID else { return }
        provider.reportOutgoingCall(with: uuid, connectedAt: connectedAt)
    }

    func updateCall(startedConnectingAt: Date) {
        guard let uuid = currentCallUUID else { return }
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: startedConnectingAt)
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("CallKit: Failed to configure audio session: \(error)")
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        print("CallKit: Provider reset")
        // End all calls
        CallManager.shared.endCall()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("CallKit: User initiated outgoing call")

        configureAudioSession()

        // Notify provider that call started connecting
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())

        // The actual WebRTC connection will be handled by CallManager
        // This is just for CallKit UI

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("CallKit: User answered call")

        configureAudioSession()

        // Accept the call via CallManager
        Task {
            do {
                try await CallManager.shared.acceptCall()
                action.fulfill()
            } catch {
                print("CallKit: Failed to accept call: \(error)")
                action.fail()
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("CallKit: User ended call")

        // End call via CallManager
        CallManager.shared.endCall()

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("CallKit: User toggled mute: \(action.isMuted)")

        // Update mute state
        if action.isMuted != CallManager.shared.isMuted {
            CallManager.shared.toggleMute()
        }

        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("CallKit: Audio session activated")
        // Audio session is now active, WebRTC can start
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("CallKit: Audio session deactivated")
    }
}
