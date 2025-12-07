//
//  MainTabView.swift
//  Privet
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatsListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Чаты")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Настройки")
                }
                .tag(1)
        }
        .tint(.whatsAppGreen)
    }
}

#Preview {
    MainTabView()
}
