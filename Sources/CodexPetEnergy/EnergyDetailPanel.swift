import SwiftUI

struct EnergyDetailPanel: View {
    let reading: EnergyReading
    let summary: ProjectUsageDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label("今日项目算力", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(resetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(EnergyVisualStyle.subtleFill, in: Capsule())
            }

            Divider()
                .overlay(EnergyVisualStyle.hairline)

            if summary.projects.isEmpty {
                Text("今天暂无项目用量")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 3) {
                    ForEach(summary.projects) { project in
                        ProjectUsageRow(project: project)
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .energyGlassCard()
    }

    private var resetText: String {
        guard let reset = reading.resetsAt else { return "重置时间 —" }
        let text = reset.formatted(
            .dateTime
                .month(.defaultDigits)
                .day()
                .hour()
                .minute()
                .locale(Locale(identifier: "zh_CN"))
        )
        return "重置 \(text)"
    }
}
