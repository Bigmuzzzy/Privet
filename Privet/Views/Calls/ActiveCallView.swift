//
//  ActiveCallView.swift
//  Privet
//
//  Active call screen
//

import SwiftUI

struct ActiveCallView: View {
    @ObservedObject var callManager = CallManager.shared
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.whatsAppDarkGreen, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Call info
                VStack(spacing: 16) {
                    // Status
                    Text(statusText)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))

                    // Avatar
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(callManager.remoteUserName?.prefix(1).uppercased() ?? "?")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        )

                    // Name
                    Text(callManager.remoteUserName ?? "Unknown")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)

                    // Duration
                    if callManager.callState == .connected {
                        Text(formattedDuration)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .monospacedDigit()
                    }
                }

                Spacer()

                // Call controls
                VStack(spacing: 40) {
                    // Mute & Speaker buttons
                    HStack(spacing: 60) {
                        // Mute button
                        CallControlButton(
                            icon: callManager.isMuted ? "mic.slash.fill" : "mic.fill",
                            label: "Mute",
                            isActive: callManager.isMuted
                        ) {
                            callManager.toggleMute()
                        }

                        // Speaker button
                        CallControlButton(
                            icon: "speaker.wave.2.fill",
                            label: "Speaker",
                            isActive: callManager.isSpeakerOn
                        ) {
                            callManager.toggleSpeaker()
                        }
                    }

                    // End call button
                    Button(action: endCall) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)

                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
            .padding()
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: callManager.callState) { _, newState in
            if newState == .ended || newState == .failed || newState == .idle {
                dismiss()
            }
        }
    }

    private var statusText: String {
        switch callManager.callState {
        case .connecting:
            return "Connecting..."
        case .connected:
            return callManager.currentCallType == .video ? "Video call" : "Audio call"
        case .ringing:
            return "Ringing..."
        default:
            return ""
        }
    }

    private var formattedDuration: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if callManager.callState == .connected {
                elapsedTime += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func endCall() {
        callManager.endCall()
        dismiss()
    }
}

// MARK: - Call Control Button

struct CallControlButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isActive ? Color.whatsAppGreen : .white)
                }

                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    ActiveCallView()
}
