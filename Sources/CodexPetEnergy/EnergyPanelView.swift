import AppKit
import SwiftUI

struct EnergyPanelView: View {
    @ObservedObject var store: EnergyStore
    let mode: EnergyPanelMode
    let onToggleProjects: () -> Void
    let onToggleQuota: () -> Void
    let onResetPosition: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            CompactQuotaRow(
                reading: store.overall,
                modelReading: store.quotaDetails.featuredCompactLimit
            )
                .frame(height: EnergyPanelMetrics.compactContentHeight)

            if mode == .projects {
                EnergyDetailPanel(
                    reading: store.overall,
                    summary: store.projectSummary
                )
            } else if mode == .quota {
                QuotaDetailPanel(summary: store.quotaDetails)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(
            width: mode.size.width,
            height: mode.size.height,
            alignment: .top
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: mode.isExpanded ? .contain : .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(
            EnergyLogic.compactStatusText(
                for: store.overall,
                modelReading: store.quotaDetails.featuredCompactLimit
            )
        )
        .accessibilityHint("右键可查看项目算力或剩余用量；左键拖动可调整位置")
        .accessibilityAction(
            named: Text(mode.isExpanded ? "关闭算力详情" : "查看项目算力详情"),
            onToggleProjects
        )
        .help("右键可查看项目算力或剩余用量；左键拖动可调整位置")
        .contextMenu {
            Button(
                mode == .projects ? "关闭项目算力" : "查看项目算力",
                action: onToggleProjects
            )
            Button(
                mode == .quota ? "关闭剩余用量" : "查看剩余用量",
                action: onToggleQuota
            )
            Divider()
            Button("恢复默认位置", action: onResetPosition)
            Divider()
            Button("退出算力条") {
                NSApp.terminate(nil)
            }
        }
    }

    private var accessibilityTitle: String {
        switch mode {
        case .compact: "Codex 剩余额度"
        case .projects: "Codex 项目算力详情"
        case .quota: "Codex 剩余用量详情"
        }
    }
}
