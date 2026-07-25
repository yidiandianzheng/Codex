import CoreGraphics

enum EnergyPanelMode: Equatable {
    case compact
    case projects
    case quota

    var size: CGSize {
        switch self {
        case .compact: EnergyPanelMetrics.baseSize
        case .projects: EnergyPanelMetrics.expandedSize
        case .quota: EnergyPanelMetrics.quotaSize
        }
    }

    var isExpanded: Bool { self != .compact }

    mutating func toggleProjects() {
        self = self == .projects ? .compact : .projects
    }

    mutating func toggleQuota() {
        self = self == .quota ? .compact : .quota
    }
}
