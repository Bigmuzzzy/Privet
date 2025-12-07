//
//  ChatsViewModel.swift
//  Privet
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var filteredChats: [Chat] = []
    @Published var searchText: String = "" {
        didSet {
            filterChats()
        }
    }
    @Published var isLoading: Bool = false

    private let chatService = ChatService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        loadChats()
    }

    private func setupBindings() {
        chatService.$chats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chats in
                self?.chats = chats
                self?.filterChats()
            }
            .store(in: &cancellables)
    }

    func loadChats() {
        guard authService.currentUser != nil else { return }
        isLoading = true

        Task {
            do {
                try await chatService.loadChats()
            } catch {
                print("Failed to load chats: \(error)")
            }
            isLoading = false
        }
    }

    func stopListening() {
        // WebSocket handles real-time updates now
    }

    func refresh() async {
        do {
            try await chatService.loadChats()
        } catch {
            print("Failed to refresh chats: \(error)")
        }
    }

    private func filterChats() {
        if searchText.isEmpty {
            filteredChats = chats
        } else {
            filteredChats = chatService.searchChats(query: searchText)
        }
    }

    func deleteChat(at offsets: IndexSet) {
        for index in offsets {
            let chat = filteredChats[index]
            Task {
                try? await chatService.deleteChat(chat.id)
            }
        }
    }
}
