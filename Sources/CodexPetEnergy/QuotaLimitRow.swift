import SwiftUI

struct QuotaLimitRow: View {
    let reading: QuotaLimitReading

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Label {
                    Text(reading.title)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: EnergyToneStyle.symbol(for: reading.remainingPercent))
                        .foregroundStyle(toneColor)
                }
                .font(.callout)
                .bold()

                Spacer(minLength: 8)

                Text("\(reading.remainingPercent)%")
                    .foregroundStyle(toneColor)
                    .font(.callout.monospacedDigit())
                    .bold()
            }

            ProgressView(value: Double(reading.remainingPercent), total: 100)
                .progressViewStyle(.linear)
                .tint(toneColor)
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                Text("窗口 \(EnergyLogic.windowDurationText(reading.windowDurationMins))")
                Spacer(minLength: 8)
                Text("重置 \(EnergyLogic.compactResetDateText(reading.resetsAt))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            EnergyVisualStyle.subtleFill,
            in: RoundedRectangle(cornerRadius: EnergyVisualStyle.rowCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: EnergyVisualStyle.rowCornerRadius)
                .stroke(EnergyVisualStyle.hairline, lineWidth: 0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.title)
        .accessibilityValue(
            "\(EnergyLogic.windowDurationText(reading.windowDurationMins))，剩余 \(reading.remainingPercent)%，\(EnergyLogic.compactResetDateText(reading.resetsAt)) 重置"
        )
    }

    private var toneColor: Color {
        EnergyToneStyle.color(for: reading.remainingPercent)
    }
}
