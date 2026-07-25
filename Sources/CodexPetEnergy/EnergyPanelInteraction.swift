import CoreGraphics

enum EnergyPanelInteraction {
    static let clickMovementThreshold: CGFloat = 4

    static func isClick(
        start: CGPoint,
        end: CGPoint,
        threshold: CGFloat = clickMovementThreshold
    ) -> Bool {
        hypot(end.x - start.x, end.y - start.y) <= threshold
    }
}
