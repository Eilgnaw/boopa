import AppKit

/// Clears a persistent glow when the user switches focus to one of the
/// `clear_on_focus` apps (e.g. their terminal) — "you're already looking".
final class FocusMonitor {
    /// Bundle identifiers that should dismiss a persistent glow on activation.
    var clearOnFocus: Set<String> = []

    private let onShouldClear: () -> Void
    private var observer: NSObjectProtocol?

    init(onShouldClear: @escaping () -> Void) {
        self.onShouldClear = onShouldClear
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let self,
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleID = app.bundleIdentifier,
                self.clearOnFocus.contains(bundleID)
            else { return }
            self.onShouldClear()
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
