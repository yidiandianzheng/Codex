import SwiftUI

struct QuotaDetailPanel: View {
    let summary: QuotaDetailSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label("剩余用量", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.headline)

                Spacer(minLength: 8)

                if let count = summary.availableResetCount {
                    QuotaResetBadge(count: count)
                }
            }

            if let overall = summary.overall {
                QuotaLimitRow(reading: overall)
            } else {
                Text("额度暂不可用")
                    .foregroundStyle(.secondary)
            }

            Divider()

            if summary.modelLimits.isEmpty {
                Text("暂无单独模型额度")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(summary.modelLimits) { limit in
                            QuotaLimitRow(reading: limit)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .energyGlassCard()
    }
}
