//
//  Color+Extensions.swift
//  Privet
//

import SwiftUI

extension Color {
    // WhatsApp цвета
    static let whatsAppGreen = Color(hex: "25D366")
    static let whatsAppDarkGreen = Color(hex: "128C7E")
    static let whatsAppLightGreen = Color(hex: "DCF8C6")
    static let whatsAppBackground = Color(hex: "ECE5DD")
    static let whatsAppChatBackground = Color(hex: "E5DDD5")
    static let whatsAppBlue = Color(hex: "34B7F1")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
