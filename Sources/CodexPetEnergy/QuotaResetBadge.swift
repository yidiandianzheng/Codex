import SwiftUI

struct QuotaResetBadge: View {
    let count: Int

    var body: some View {
        Label("\(count) 次重置", systemImage: "arrow.clockwise")
            .font(.caption.monospacedDigit())
            .foregroundStyle(EnergyVisualStyle.computeAccent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                EnergyVisualStyle.computeAccent.opacity(0.13),
                in: Capsule()
            )
            .accessibilityLabel("可用重置次数 \(count)")
    }
}
