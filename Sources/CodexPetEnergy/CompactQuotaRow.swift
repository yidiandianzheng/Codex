import SwiftUI

struct CompactQuotaRow: View {
    let reading: EnergyReading
    let modelReading: QuotaLimitReading?

    var body: some View {
        HStack(spacing: 5) {
            CompactQuotaBadge(
                label: "总",
                systemImage: "gauge.with.dots.needle.50percent",
                remainingPercent: reading.remainingPercent,
                labelColor: .secondary
            )

            Text("\(EnergyLogic.compactResetDateText(reading.resetsAt)) · \(daysText)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .frame(maxWidth: .infinity)

            CompactQuotaBadge(
                label: "5.3",
                systemImage: "bolt.fill",
                remainingPercent: modelReading?.remainingPercent,
                labelColor: EnergyVisualStyle.modelAccent
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .energyGlassCard(cornerRadius: EnergyVisualStyle.compactCornerRadius)
        .help(helpText)
    }

    private var daysText: String {
        EnergyLogic.remainingDays(until: reading.resetsAt).map { "\($0)天" } ?? "—"
    }

    private var helpText: String {
        let overall: String
        if let percent = reading.remainingPercent, let reset = reading.resetsAt {
            overall = "总额度剩余 \(percent)%；\(reset.formatted(date: .abbreviated, time: .shortened)) 重置"
        } else {
            overall = "总额度暂不可用"
        }

        let model = modelReading.map {
            "GPT-5.3 剩余 \($0.remainingPercent)%"
        } ?? "GPT-5.3 暂不可用"
        return "\(overall)；\(model)；右键查看完整额度"
    }

}
