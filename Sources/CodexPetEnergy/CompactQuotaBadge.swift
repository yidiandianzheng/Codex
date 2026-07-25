import SwiftUI

struct CompactQuotaBadge: View {
    let label: String
    let systemImage: String
    let remainingPercent: Int?
    let labelColor: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(labelColor)
                .accessibilityHidden(true)

            Text(label)
                .font(.caption)
                .foregroundStyle(labelColor)

            Text(remainingPercent.map { "\($0)%" } ?? "—")
                .font(.callout.monospacedDigit())
                .foregroundStyle(EnergyToneStyle.color(for: remainingPercent))
                .bold()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            EnergyToneStyle.color(for: remainingPercent).opacity(0.11),
            in: Capsule()
        )
    }
}
