//
//  IncomingCallView.swift
//  Privet
//
//  Incoming call screen
//

import SwiftUI

struct IncomingCallView: View {
    @ObservedObject var callManager = CallManager.shared
    @State private var isAccepting = false
    @State private var showError = false
    @State private var errorMessage = ""

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

                // Caller info
                VStack(spacing: 16) {
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

                    // Call type
                    Text(callTypeText)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Call action buttons
                HStack(spacing: 80) {
                    // Decline button
                    Button(action: declineCall) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)

                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }

                    // Accept button
                    Button(action: acceptCall) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 70, height: 70)

                            Image(systemName: "phone.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isAccepting)
                }
                .padding(.bottom, 60)
            }
            .padding()

            // Loading overlay
            if isAccepting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .alert("Call Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                callManager.endCall()
            }
        } message: {
            Text(errorMessage)
        }
    }

    private var callTypeText: String {
        switch callManager.currentCallType {
        case .audio:
            return "Incoming audio call..."
        case .video:
            return "Incoming video call..."
        case .none:
            return "Incoming call..."
        }
    }

    private func acceptCall() {
        isAccepting = true

        Task {
            do {
                try await callManager.acceptCall()
            } catch {
                await MainActor.run {
                    isAccepting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func declineCall() {
        callManager.rejectCall()
    }
}

#Preview {
    IncomingCallView()
}
