//
//  ContentView.swift
//  Privet
//
//  Created by Mike on 06.12.2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var callManager = CallManager.shared

    var body: some View {
        ZStack {
            // Main app view
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .animation(.easeInOut, value: authService.isAuthenticated)

            // Call overlays
            if authService.isAuthenticated {
                // Incoming call view
                if callManager.callState == .incoming {
                    IncomingCallView()
                        .transition(.move(edge: .bottom))
                        .zIndex(100)
                }

                // Active call view
                if callManager.callState == .connecting ||
                   callManager.callState == .connected ||
                   callManager.callState == .ringing {
                    ActiveCallView()
                        .transition(.move(edge: .bottom))
                        .zIndex(99)
                }
            }
        }
        .animation(.easeInOut, value: callManager.callState)
    }
}

#Preview {
    ContentView()
}
