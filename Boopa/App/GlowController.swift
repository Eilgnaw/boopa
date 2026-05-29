import AppKit
import SwiftUI

/// Owns the per-screen overlay windows and the show/clear lifecycle, including
/// one-shot auto-fade, persistent fallback timeout, and focus-driven clearing.
@MainActor
final class GlowController {
    private(set) var isShowing = false

    private var windows: [OverlayWindow] = []
    private var currentStyle: Theme?
    private var currentMode: GlowMode = .persistent
    private var clearTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isShowing, let style = self.currentStyle else { return }
            self.buildWindows(style: style)
        }
    }

    // MARK: - Public API

    func show(style: Theme, autoClearSeconds: Double, duration: Double?) {
        clearTimer?.invalidate()
        currentStyle = style
        currentMode = style.modeKind
        isShowing = true
        buildWindows(style: style)

        switch style.modeKind {
        case .oneshot:
            let length = duration ?? Double(max(1, style.flashes)) * style.period
            scheduleClear(after: length)
        case .persistent:
            let timeout = duration ?? autoClearSeconds
            if timeout > 0 { scheduleClear(after: timeout) }
        }
    }

    func clear() {
        clearTimer?.invalidate()
        clearTimer = nil
        isShowing = false
        currentStyle = nil
        let closing = windows
        windows = []
        for window in closing {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }

    /// Clear only if a *persistent* glow is showing (one-shots fade on their own).
    func clearForFocusChange() {
        guard isShowing, currentMode == .persistent else { return }
        clear()
    }

    // MARK: - Windows

    private func buildWindows(style: Theme) {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            let host = NSHostingView(rootView: GlowView(style: style, notch: NotchGeometry.from(screen)))
            // Ignore the safe area so the glow reaches the physical top edge beside
            // the notch instead of being pushed below it.
            host.safeAreaRegions = []
            host.frame = CGRect(origin: .zero, size: screen.frame.size)
            host.autoresizingMask = [.width, .height]
            window.contentView = host
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
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

extension NotchGeometry {
    /// Notch geometry for `screen` in overlay-local points (top-left origin), or
    /// `nil` when the screen has no notch — e.g. most external displays.
    static func from(_ screen: NSScreen) -> NotchGeometry? {
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return nil }
        let width = screen.frame.width
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchGeometry(height: height, leftX: left.width, rightX: width - right.width)
        }
        // Fallback: assume a centered notch of a typical width.
        let notchWidth: CGFloat = 200
        return NotchGeometry(height: height, leftX: (width - notchWidth) / 2, rightX: (width + notchWidth) / 2)
    }
}
