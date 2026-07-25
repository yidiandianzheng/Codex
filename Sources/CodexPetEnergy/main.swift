import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = EnergyStore()
    private let rateLimitClient = CodexRateLimitClient()
    private let projectUsageMonitor = ProjectUsageMonitor()
    private let tracker = CodexWindowTracker()
    private var panelController: EnergyPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = EnergyPanelController(store: store)

        rateLimitClient.onSnapshot = { [weak self] result in
            self?.store.apply(result)
        }
        rateLimitClient.onUnavailable = { [weak self] in
            self?.store.markUnavailable()
        }
        projectUsageMonitor.onUpdate = { [weak self] summary in
            self?.store.apply(summary)
        }
        tracker.onLocation = { [weak self] location in
            self?.panelController?.update(for: location)
        }

        rateLimitClient.start()
        projectUsageMonitor.start()
        tracker.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        rateLimitClient.stop()
        projectUsageMonitor.stop()
        tracker.stop()
    }
}

if CommandLine.arguments.contains("--self-test") {
    exit(SelfTest.run() ? EXIT_SUCCESS : EXIT_FAILURE)
} else {
    MainActor.assumeIsolated {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
