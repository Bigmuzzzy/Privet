//
//  ChatsListView.swift
//  Privet
//

import SwiftUI

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsViewModel()
    @State private var showNewChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.filteredChats.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    chatsList
                }
            }
            .navigationTitle("Чаты")
            .searchable(text: $viewModel.searchText, prompt: "Поиск")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.whatsAppGreen)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    private var chatsList: some View {
        List {
            ForEach(viewModel.filteredChats) { chat in
                NavigationLink(destination: ConversationView(chat: chat)) {
                    ChatRowView(chat: chat)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .onDelete(perform: viewModel.deleteChat)
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("Нет чатов")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Начните новый разговор,\nнажав на кнопку выше")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showNewChat = true }) {
                Text("Новый чат")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.whatsAppGreen)
                    .cornerRadius(25)
            }
            .padding(.top, 8)
        }
    }
}

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var chatService = ChatService.shared
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var isCreatingChat = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Поиск...")
                } else if searchResults.isEmpty && hasSearched {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Пользователи не найдены")
                            .foregroundColor(.secondary)
                    }
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Введите номер телефона\nдля поиска пользователя")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List(searchResults) { user in
                        Button(action: {
                            startChat(with: user)
                        }) {
                            HStack(spacing: 12) {
                                AvatarView(
                                    name: user.displayName,
                                    size: 44,
                                    imageURL: user.avatarUrl,
                                    isOnline: user.isOnline ?? false
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("@\(user.username)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if isCreatingChat {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isCreatingChat)
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Поиск по номеру телефона")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    searchResults = []
                    hasSearched = false
                }
            }
            .navigationTitle("Новый чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isCreatingChat)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Найти") {
                        performSearch()
                    }
                    .disabled(searchText.isEmpty || isSearching)
                }
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        hasSearched = true

        Task {
            do {
                searchResults = try await chatService.searchUsers(username: searchText)
            } catch {
                print("Search error: \(error)")
                searchResults = []
            }
            isSearching = false
        }
    }

    private func startChat(with user: User) {
        isCreatingChat = true

        Task {
            do {
                _ = try await chatService.getOrCreatePrivateChat(with: user.id)
                await MainActor.run {
                    isCreatingChat = false
                    dismiss()
                }
            } catch {
                print("Error creating chat: \(error)")
                await MainActor.run {
                    isCreatingChat = false
                }
            }
        }
    }
}

#Preview {
    ChatsListView()
}
