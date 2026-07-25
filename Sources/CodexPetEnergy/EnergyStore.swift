import Combine
import Foundation
import SwiftUI

@MainActor
final class EnergyStore: ObservableObject {
    @Published private(set) var overall = EnergyReading.unavailable
    @Published private(set) var quotaDetails = QuotaDetailSummary.unavailable
    @Published private(set) var projectSummary = ProjectUsageDaySummary.empty

    func apply(_ result: RateLimitReadResult) {
        let reading = EnergyLogic.overallReading(from: result.rateLimits)
        let details = EnergyLogic.quotaDetailSummary(from: result)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            overall = reading
            quotaDetails = details
        }
    }

    func apply(_ summary: ProjectUsageDaySummary) {
        projectSummary = summary
    }

    func markUnavailable() {
        overall = .unavailable
        quotaDetails = .unavailable
    }
}
