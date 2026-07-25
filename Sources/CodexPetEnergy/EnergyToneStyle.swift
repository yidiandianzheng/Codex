import SwiftUI

enum EnergyToneStyle {
    static func color(for remainingPercent: Int?) -> Color {
        switch EnergyLogic.tone(for: remainingPercent) {
        case .green: Color(red: 0.20, green: 0.78, blue: 0.35)
        case .yellow: Color(red: 1.00, green: 0.63, blue: 0.06)
        case .red: Color(red: 1.00, green: 0.23, blue: 0.19)
        case .unavailable: Color.secondary
        }
    }

    static func symbol(for remainingPercent: Int?) -> String {
        switch EnergyLogic.tone(for: remainingPercent) {
        case .green: "checkmark.circle.fill"
        case .yellow: "exclamationmark.circle.fill"
        case .red: "exclamationmark.triangle.fill"
        case .unavailable: "questionmark.circle"
        }
    }
}
