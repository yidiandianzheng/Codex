import AppKit
import CoreGraphics

struct CodexWindowLocation: Equatable {
    let frame: CGRect
    let screenVisibleFrame: CGRect
}

final class CodexWindowTracker {
    var onLocation: ((CodexWindowLocation?) -> Void)?

    private var timer: DispatchSourceTimer?
    private var lastLocation: CodexWindowLocation?

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(40))
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.openai.codex" else {
            update(nil)
            return
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            update(nil)
            return
        }

        guard let cgFrame = windows.lazy.compactMap(Self.codexMainWindowCandidate).first,
              let location = Self.convertToAppKit(cgFrame)
        else {
            update(nil)
            return
        }
        update(location)
    }

    private func update(_ location: CodexWindowLocation?) {
        guard location != lastLocation else { return }
        lastLocation = location
        onLocation?(location)
    }

    static func codexMainWindowCandidate(_ info: [String: Any]) -> CGRect? {
        guard let owner = info[kCGWindowOwnerName as String] as? String,
              owner.localizedCaseInsensitiveContains("ChatGPT"),
              let layer = info[kCGWindowLayer as String] as? Int,
              layer == 0,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              frame.width >= 520,
              frame.height >= 320
        else { return nil }
        if let alpha = info[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue <= 0.01 {
            return nil
        }
        return frame
    }

    private static func convertToAppKit(_ cgFrame: CGRect) -> CodexWindowLocation? {
        let center = CGPoint(x: cgFrame.midX, y: cgFrame.midY)
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let displayBounds = CGDisplayBounds(displayID)
            guard displayBounds.contains(center) else { continue }

            let x = screen.frame.minX + (cgFrame.minX - displayBounds.minX)
            let y = screen.frame.maxY - (cgFrame.minY - displayBounds.minY) - cgFrame.height
            return CodexWindowLocation(
                frame: CGRect(x: x, y: y, width: cgFrame.width, height: cgFrame.height),
                screenVisibleFrame: screen.visibleFrame
            )
        }
        return nil
    }
}
