import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let glow = GlowController()
    private var ipc: IPCListener?
    private var focus: FocusMonitor?
    private var statusItem: NSStatusItem?
    private lazy var settings = SettingsWindow()
    private var config = BoopaConfig.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        BoopaConfig.writeSampleConfigIfMissing()
        setUpStatusItem()

        focus = FocusMonitor { [weak self] in self?.glow.clearForFocusChange() }
        focus?.clearOnFocus = Set(config.clearOnFocus)

        ipc = IPCListener { [weak self] command in self?.handle(command) }
    }

    // MARK: - Command handling

    private func handle(_ command: WireCommand) {
        // Reload config so behavioral settings (clear_on_focus, auto_clear_seconds) stay current.
        config = BoopaConfig.load()
        focus?.clearOnFocus = Set(config.clearOnFocus)

        switch command.action {
        case .clear:
            glow.clear()
        case .show:
            guard var style = command.style else { return }
            // If the user is already looking at a clear_on_focus app (e.g. their terminal),
            // a persistent beacon would just nag — downgrade it to a brief one-shot flash
            // that fades on its own instead of staying lit forever.
            if style.modeKind == .persistent,
               let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               config.clearOnFocus.contains(front) {
                style = style.with(mode: .oneshot)
            }
            glow.show(style: style, autoClearSeconds: config.autoClearSeconds, duration: command.duration)
            updateDismissItem()
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(named: "booopy44")
            image?.isTemplate = true // render monochrome so it adapts to the menu bar
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let dismiss = NSMenuItem(title: String(localized: "Dismiss Glow"), action: #selector(dismissGlow), keyEquivalent: "")
        dismiss.target = self
        dismiss.identifier = .dismiss
        menu.addItem(dismiss)

        let test = NSMenuItem(title: String(localized: "Test Glow"), action: #selector(testGlow), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        menu.addItem(.separator())

        let focusItem = NSMenuItem(title: String(localized: "Clear on Focus…"), action: #selector(openFocusSettings), keyEquivalent: "")
        focusItem.target = self
        menu.addItem(focusItem)

        let login = NSMenuItem(title: String(localized: "Launch at Login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.identifier = .launchAtLogin
        menu.addItem(login)

        let star = NSMenuItem(title: String(localized: "Source Code"), action: #selector(openRepo), keyEquivalent: "")
        star.target = self
        menu.addItem(star)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: String(localized: "Quit Boopa"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func updateDismissItem() {
        guard let item = statusItem?.menu?.item(withIdentifier: .dismiss) else { return }
        item.isEnabled = glow.isShowing
    }

    @objc private func dismissGlow() { glow.clear() }

    @objc private func testGlow() {
        config = BoopaConfig.load()
        let theme = config.theme(named: nil).with(mode: .oneshot)
        glow.show(style: theme, autoClearSeconds: config.autoClearSeconds, duration: nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openRepo() { NSWorkspace.shared.open(BoopaLinks.repo) }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Boopa: launch-at-login toggle failed: \(error)")
        }
    }

    // MARK: - Clear on Focus settings

    @objc private func openFocusSettings() {
        settings.show { [weak self] ids in
            BoopaConfig.updateClearOnFocus(ids.sorted())
            self?.config = BoopaConfig.load()
            self?.focus?.clearOnFocus = ids
        }
    }
}

// MARK: - NSMenuDelegate (refresh dynamic items on open)

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withIdentifier: .dismiss)?.isEnabled = glow.isShowing
        menu.item(withIdentifier: .launchAtLogin)?.state =
            (SMAppService.mainApp.status == .enabled) ? .on : .off
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let dismiss = NSUserInterfaceItemIdentifier("boopa.dismiss")
    static let launchAtLogin = NSUserInterfaceItemIdentifier("boopa.launchAtLogin")
}

private extension NSMenu {
    func item(withIdentifier id: NSUserInterfaceItemIdentifier) -> NSMenuItem? {
        items.first { $0.identifier == id }
    }
}
