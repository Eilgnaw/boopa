import AppKit
import SwiftUI

/// Owns the per-screen overlay windows for the traffic-light beacon and its show/clear
/// lifecycle (one-shot auto-fade, persistent fallback timeout, focus-driven clearing).
/// Deliberately separate from `GlowController` so the two beacons never interfere.
@MainActor
final class TrafficLightController {
    private(set) var isShowing = false

    private var windows: [OverlayWindow] = []
    private var currentSpec: TrafficSpec?
    private var currentMode: GlowMode = .persistent
    private var clearTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isShowing, let spec = self.currentSpec else { return }
            self.buildWindows(spec: spec)
        }
    }

    // MARK: - Public API

    func show(spec: TrafficSpec, autoClearSeconds: Double, duration: Double?) {
        clearTimer?.invalidate()
        currentSpec = spec
        currentMode = spec.modeKind
        isShowing = true
        buildWindows(spec: spec)

        switch spec.modeKind {
        case .oneshot:
            scheduleClear(after: duration ?? 2.5)
        case .persistent:
            let timeout = duration ?? autoClearSeconds
            if timeout > 0 { scheduleClear(after: timeout) }
        }
    }

    func clear() {
        clearTimer?.invalidate()
        clearTimer = nil
        isShowing = false
        currentSpec = nil
        let closing = windows
        windows = []
        for window in closing {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }

    /// Clear only if a *persistent* beacon is showing (one-shots fade on their own).
    func clearForFocusChange() {
        guard isShowing, currentMode == .persistent else { return }
        clear()
    }

    // MARK: - Windows

    /// One overlay per screen — notched displays pull the bar from the notch, the rest
    /// from their top-center — so the beacon shows up on external monitors too.
    private func buildWindows(spec: TrafficSpec) {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            let host = NSHostingView(rootView: TrafficLightView(spec: spec, notch: NotchGeometry.from(screen)))
            // Ignore the safe area so the beacon can sit right at / beside the notch.
            host.safeAreaRegions = []
            host.frame = CGRect(origin: .zero, size: screen.frame.size)
            host.autoresizingMask = [.width, .height]
            window.contentView = host
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                window.animator().alphaValue = 1
            }
            return window
        }
    }

    private func scheduleClear(after seconds: TimeInterval) {
        clearTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.clear() }
        }
    }
}
