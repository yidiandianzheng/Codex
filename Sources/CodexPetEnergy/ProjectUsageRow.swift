import SwiftUI

struct ProjectUsageRow: View {
    let project: ProjectUsageReading

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(project.projectName)
                    .font(.callout)
                    .bold()
                    .lineLimit(2)
                    .layoutPriority(1)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Text(TokenFormatting.compact(project.totals.totalTokens))
                .font(.callout.monospacedDigit())
                .bold()
                .foregroundStyle(EnergyVisualStyle.computeAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minWidth: 66, alignment: .trailing)
                .background(
                    EnergyVisualStyle.computeAccent.opacity(0.13),
                    in: Capsule()
                )
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(EnergyVisualStyle.subtleFill, in: RoundedRectangle(cornerRadius: EnergyVisualStyle.rowCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: EnergyVisualStyle.rowCornerRadius)
                .stroke(EnergyVisualStyle.hairline, lineWidth: 0.6)
        }
        .help(detailText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(project.projectName)
        .accessibilityValue("\(metadataText)；总 Token \(TokenFormatting.exact(project.totals.totalTokens))；\(detailText)")
    }

    private var metadataText: String {
        let turns = project.totals.turnCount
        let average = turns > 0 ? project.totals.totalTokens / turns : 0
        let time = project.lastActivity.formatted(
            .dateTime
                .hour()
                .minute()
                .locale(Locale(identifier: "zh_CN"))
        )
        return "\(turns)轮 · 均 \(TokenFormatting.compact(average)) · \(time)"
    }

    private var detailText: String {
        let totals = project.totals
        return [
            "输入 \(TokenFormatting.exact(totals.inputTokens))",
            "输出 \(TokenFormatting.exact(totals.outputTokens))",
            "推理 \(TokenFormatting.exact(totals.reasoningTokens))",
            "缓存 \(TokenFormatting.exact(totals.cachedInputTokens))",
        ].joined(separator: " · ")
    }
}
