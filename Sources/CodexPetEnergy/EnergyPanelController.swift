import AppKit
import SwiftUI

@MainActor
final class EnergyPanelController: NSObject, NSWindowDelegate {
    private let store: EnergyStore
    private let panel: NSPanel
    private let hostingView: DraggableHostingView<EnergyPanelView>
    private var mode = EnergyPanelMode.compact
    private var customOffset = EnergyPanelPositionStore.load()
    private var lastLocation: CodexWindowLocation?
    private var lastDefaultOrigin: CGPoint?
    private var isApplyingFrame = false

    private var panelSize: CGSize { mode.size }

    init(store: EnergyStore) {
        self.store = store
        hostingView = DraggableHostingView(
            rootView: EnergyPanelView(
                store: store,
                mode: .compact,
                onToggleProjects: {},
                onToggleQuota: {},
                onResetPosition: {}
            )
        )
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: EnergyPanelMetrics.baseSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        hostingView.rootView = EnergyPanelView(
            store: store,
            mode: mode,
            onToggleProjects: { [weak self] in self?.toggleProjectDetails() },
            onToggleQuota: { [weak self] in self?.toggleQuotaDetails() },
            onResetPosition: { [weak self] in self?.resetPosition() }
        )
        panel.contentView = hostingView
        panel.delegate = self
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        panel.isReleasedWhenClosed = false
    }

    func update(for location: CodexWindowLocation?) {
        lastLocation = location
        guard let location else {
            panel.orderOut(nil)
            return
        }

        let defaultOrigin = CodexHeaderLayout.defaultPanelOrigin(
            for: location,
            panelSize: panelSize
        )
        lastDefaultOrigin = defaultOrigin
        let origin = CodexHeaderLayout.panelOrigin(
            for: location,
            panelSize: panelSize,
            offset: customOffset
        )
        isApplyingFrame = true
        panel.setFrame(CGRect(origin: origin, size: panelSize), display: true)
        isApplyingFrame = false
        panel.orderFrontRegardless()
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingFrame, let defaultOrigin = lastDefaultOrigin else { return }
        let origin = panel.frame.origin
        customOffset = CGSize(
            width: origin.x - defaultOrigin.x,
            height: origin.y - defaultOrigin.y
        )
        EnergyPanelPositionStore.save(customOffset)
    }

    private func resetPosition() {
        customOffset = .zero
        EnergyPanelPositionStore.reset()
        update(for: lastLocation)
    }

    private func toggleProjectDetails() {
        mode.toggleProjects()
        refreshRootView()
    }

    private func toggleQuotaDetails() {
        mode.toggleQuota()
        refreshRootView()
    }

    private func refreshRootView() {
        hostingView.rootView = EnergyPanelView(
            store: store,
            mode: mode,
            onToggleProjects: { [weak self] in self?.toggleProjectDetails() },
            onToggleQuota: { [weak self] in self?.toggleQuotaDetails() },
            onResetPosition: { [weak self] in self?.resetPosition() }
        )
        update(for: lastLocation)
    }

}

enum CodexHeaderLayout {
    // Match the user-marked header slot: reserve the avatar/title group on the
    // left and the help/control group on the right, then center inside the
    // remaining red-box area instead of centering in the whole window.
    static let headerLeadingReservedWidth: CGFloat = 126
    static let headerTrailingReservedWidth: CGFloat = 68
    static let compactTopInset: CGFloat = 10
    static let sideInset: CGFloat = 12

    static func defaultPanelOrigin(
        for location: CodexWindowLocation,
        panelSize: CGSize
    ) -> CGPoint {
        let window = location.frame
        let visible = location.screenVisibleFrame
        let slotMinX = window.minX + headerLeadingReservedWidth
        let slotMaxX = window.maxX - headerTrailingReservedWidth
        let desiredX = slotMinX + (slotMaxX - slotMinX - panelSize.width) / 2
        let desiredY = window.maxY - compactTopInset - panelSize.height

        let windowMinX = max(window.minX + sideInset, visible.minX)
        let windowMaxX = min(window.maxX - sideInset - panelSize.width, visible.maxX - panelSize.width)
        let x = clamped(desiredX, minimum: windowMinX, maximum: windowMaxX)

        let windowMinY = max(window.minY + sideInset, visible.minY)
        let windowMaxY = min(window.maxY - panelSize.height, visible.maxY - panelSize.height)
        let y = clamped(desiredY, minimum: windowMinY, maximum: windowMaxY)
        return CGPoint(x: x, y: y)
    }

    static func panelOrigin(
        for location: CodexWindowLocation,
        panelSize: CGSize,
        offset: CGSize
    ) -> CGPoint {
        let base = defaultPanelOrigin(for: location, panelSize: panelSize)
        let visible = location.screenVisibleFrame
        let desiredX = base.x + offset.width
        let desiredY = base.y + offset.height
        let x = clamped(
            desiredX,
            minimum: visible.minX,
            maximum: visible.maxX - panelSize.width
        )
        let y = clamped(
            desiredY,
            minimum: visible.minY,
            maximum: visible.maxY - panelSize.height
        )
        return CGPoint(x: x, y: y)
    }

    private static func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else { return minimum }
        return min(max(value, minimum), maximum)
    }
}

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            super.mouseDown(with: event)
            return
        }
        window.performDrag(with: event)
    }
}

enum EnergyPanelPositionStore {
    private static let offsetXKey = "energy-panel-custom-offset-x"
    private static let offsetYKey = "energy-panel-custom-offset-y"

    static func load(defaults: UserDefaults = .standard) -> CGSize {
        guard defaults.object(forKey: offsetXKey) != nil,
              defaults.object(forKey: offsetYKey) != nil
        else { return .zero }
        return CGSize(
            width: defaults.double(forKey: offsetXKey),
            height: defaults.double(forKey: offsetYKey)
        )
    }

    static func save(_ offset: CGSize, defaults: UserDefaults = .standard) {
        defaults.set(Double(offset.width), forKey: offsetXKey)
        defaults.set(Double(offset.height), forKey: offsetYKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: offsetXKey)
        defaults.removeObject(forKey: offsetYKey)
    }
}
