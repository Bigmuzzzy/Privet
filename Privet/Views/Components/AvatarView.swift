//
//  AvatarView.swift
//  Privet
//

import SwiftUI

struct AvatarView: View {
    let name: String
    let size: CGFloat
    let imageURL: String?
    var isOnline: Bool = false

    private var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let second = components[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var backgroundColor: Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .mint,
            .teal, .cyan, .blue, .indigo, .purple, .pink
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageURL = imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }

            if isOnline {
                Circle()
                    .fill(Color.whatsAppGreen)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(backgroundColor.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarView(name: "Алексей Петров", size: 60, imageURL: nil, isOnline: true)
        AvatarView(name: "Мария", size: 50, imageURL: nil, isOnline: false)
        AvatarView(name: "Дмитрий", size: 40, imageURL: nil)
    }
}
