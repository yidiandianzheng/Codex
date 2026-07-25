import Foundation

enum TokenFormatting {
    static func compact(_ value: Int) -> String {
        let magnitude: Double
        let suffix: String

        if value >= 1_000_000 {
            magnitude = Double(value) / 1_000_000
            suffix = "M"
        } else if value >= 1_000 {
            magnitude = Double(value) / 1_000
            suffix = "K"
        } else {
            return String(value)
        }

        let fractionLength = magnitude >= 10 ? 0 : 1
        let number = magnitude.formatted(
            .number
                .precision(.fractionLength(fractionLength))
                .locale(Locale(identifier: "zh_CN"))
        )
        return "\(number)\(suffix)"
    }

    static func exact(_ value: Int) -> String {
        value.formatted(
            .number
                .grouping(.automatic)
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}
