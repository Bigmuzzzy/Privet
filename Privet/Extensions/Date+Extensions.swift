//
//  Date+Extensions.swift
//  Privet
//

import Foundation

extension Date {
    func chatTimeString() -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Вчера"
        } else if calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "EE"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: self)
        }
    }

    func messageTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    func lastSeenString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)

        if let minutes = components.minute, minutes < 1 {
            return "в сети"
        } else if let minutes = components.minute, let hours = components.hour, hours == 0 {
            return "был(а) \(minutes) мин. назад"
        } else if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "был(а) сегодня в \(formatter.string(from: self))"
        } else if calendar.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "был(а) вчера в \(formatter.string(from: self))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return "был(а) \(formatter.string(from: self))"
        }
    }
}
