import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.32, green: 0.45, blue: 0.96)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .underPageBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let subtle = Color.primary.opacity(0.055)
    static let line = Color.primary.opacity(0.11)
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

extension Date {
    var russianDayTitle: String {
        formatted(
            Date.FormatStyle(date: .complete, time: .omitted)
                .locale(Locale(identifier: "ru_RU"))
        )
    }

    var russianShortDay: String {
        formatted(
            Date.FormatStyle()
                .day(.twoDigits)
                .month(.wide)
                .year()
                .locale(Locale(identifier: "ru_RU"))
        )
    }
}

extension String {
    var capitalizingFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

func timeText(minutes: Int) -> String {
    let clamped = min(max(minutes, 0), 1_440)
    return String(format: "%02d:%02d", clamped / 60, clamped % 60)
}

func durationText(minutes: Int) -> String {
    let hours = minutes / 60
    let rest = minutes % 60
    if hours == 0 { return "\(rest) мин" }
    if rest == 0 { return "\(hours) ч" }
    return "\(hours) ч \(rest) мин"
}
