import AppKit
import ArgumentParser

// MARK: - Root

struct BoopaCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "boopa",
        abstract: "Flash a glowing ring around the screen edges to signal that an agent needs attention.",
        subcommands: [Flash.self, Attention.self, Light.self, Clear.self, Themes.self, Status.self, Install.self, Uninstall.self, Quit.self]
    )

    /// Subcommand names used by BoopaMain to decide CLI vs agent mode.
    static let knownSubcommands: Set<String> = [
        "flash", "attention", "light", "clear", "themes", "status", "install", "uninstall", "quit", "help",
    ]
}

// MARK: - Shared style flags

struct StyleOptions: ParsableArguments {
    @Option(name: .long, help: "Theme name from your config (else the default theme).")
    var theme: String?

    @Option(name: .long, help: "Glow color: hex (#FF3B30) or a name (red, green, blue, …).")
    var color: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Edges: all | top | bottom | left | right.")
    var edges: [String] = []

    @Option(name: .long, help: "Glow band width in points.")
    var thickness: Double?

    @Option(name: .long, help: "Glow softness (blur radius).")
    var blur: Double?

    @Option(name: .long, help: "Animation: breathe | pulse | comet | blink | solid.")
    var animation: String?

    @Option(name: .long, help: "Animation cycles per second.")
    var speed: Double?

    @Option(name: .long, help: "Brightness/opacity, 0..1.")
    var intensity: Double?

    @Option(name: .long, help: "Duration in seconds (one-shot length, or persistent fallback timeout).")
    var duration: Double?

    func resolvedTheme(_ config: BoopaConfig) -> Theme {
        config.theme(named: theme).applying(StyleOverrides(
            color: color,
            edges: edges.isEmpty ? nil : edges,
            thickness: thickness,
            blur: blur,
            animation: animation,
            speed: speed,
            intensity: intensity
        ))
    }
}

// MARK: - Glow commands

struct Flash: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "One-shot pulse that fades out automatically.")
    @OptionGroup var style: StyleOptions

    func run() throws {
        let config = BoopaConfig.load()
        let theme = style.resolvedTheme(config).with(mode: .oneshot)
        Agent.ensureRunningThenSend(WireCommand(action: .show, style: theme, duration: style.duration))
    }
}

struct Attention: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Persistent glow until cleared (or you focus a clear_on_focus app).")
    @OptionGroup var style: StyleOptions

    func run() throws {
        let config = BoopaConfig.load()
        let theme = style.resolvedTheme(config).with(mode: .persistent)
        Agent.ensureRunningThenSend(WireCommand(action: .show, style: theme, duration: style.duration))
    }
}

struct Clear: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Turn off any active glow.")

    func run() throws {
        // Nothing to clear if the agent isn't running.
        if Agent.isRunning() {
            Agent.send(WireCommand(action: .clear, style: nil, duration: nil))
        }
    }
}

// MARK: - Traffic-light command

struct Light: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "light",
        abstract: "Drop a traffic-light beacon from the notch; lit lamps signal status.",
        discussion: """
        Lamps are red, yellow, green. Pass the ones to light as arguments
        (default: red). Examples:
          boopa light green            # all-clear / done
          boopa light red              # blocked / needs you
          boopa light yellow           # thinking / in progress
          boopa light red yellow       # light two at once
        Stays up until `boopa clear` (or focusing a clear_on_focus app); use
        --oneshot or --duration to fade it out on its own.
        """
    )

    @Argument(help: "Lamps to light: red, yellow, green. Combine freely. Defaults to red.")
    var colors: [String] = []

    @Option(name: .long, help: "Bar width in points. Defaults to the notch width.")
    var size: Double?

    @Option(name: .long, help: "Duration in seconds before auto-clearing.")
    var duration: Double?

    @Flag(name: .long, help: "Fade out automatically instead of staying until cleared.")
    var oneshot: Bool = false

    func run() throws {
        var spec = TrafficSpec()
        let valid = colors.compactMap { TrafficColor(rawValue: $0.lowercased())?.rawValue }
        if !valid.isEmpty { spec.lit = valid }
        if let size { spec.size = size }
        spec.mode = (oneshot ? GlowMode.oneshot : .persistent).rawValue
        Agent.ensureRunningThenSend(WireCommand(action: .show, traffic: spec, duration: duration))
    }
}

// MARK: - Info / management commands

struct Themes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List configured themes.")

    func run() throws {
        let config = BoopaConfig.load()
        print("Config: \(BoopaConfig.configURL.path)")
        print("Default theme: \(config.defaultTheme)\n")
        for name in config.themeNames {
            let t = config.themes[name]!
            let marker = name == config.defaultTheme ? "*" : " "
            print("\(marker) \(name.padding(toLength: 12, withPad: " ", startingAt: 0)) \(t.color)  \(t.animation)  \(t.mode)")
        }
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show whether the Boopa agent is running.")

    func run() throws {
        let running = Agent.isRunning()
        print("Agent: \(running ? "running" : "not running")")
        if let url = Agent.appURL() { print("App:   \(url.path)") }
        let cfg = BoopaConfig.configURL
        let exists = FileManager.default.fileExists(atPath: cfg.path)
        print("Config: \(cfg.path)\(exists ? "" : "  (not created yet)")")
        let config = BoopaConfig.load()
        print("clear_on_focus (\(config.clearOnFocus.count)): \(config.clearOnFocus.joined(separator: ", "))")
    }
}

struct Install: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Symlink `boopa` onto your PATH.")

    func run() throws {
        guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            throw ValidationError("Could not locate the Boopa executable.")
        }
        let target = exe.path
        let candidates = ["/usr/local/bin", "\(NSHomeDirectory())/.local/bin"]
        for dir in candidates {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            guard FileManager.default.isWritableFile(atPath: dir) else { continue }
            let link = "\(dir)/boopa"
            try? FileManager.default.removeItem(atPath: link)
            do {
                try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
            } catch {
                continue
            }
            print("Installed: \(link) -> \(target)")
            if !pathContains(dir) {
                print("Note: \(dir) is not on your PATH. Add it, e.g.:\n  echo 'export PATH=\"\(dir):$PATH\"' >> ~/.zshrc")
            }
            // Seed a starter config so themes are discoverable.
            if let written = BoopaConfig.writeSampleConfigIfMissing() {
                print("Wrote starter config: \(written.path)")
            }
            return
        }
        throw ValidationError("No writable install directory (tried \(candidates.joined(separator: ", "))). Try `sudo`.")
    }

    private func pathContains(_ dir: String) -> Bool {
        (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").contains(Substring(dir))
    }
}

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove the `boopa` PATH symlink.")

    func run() throws {
        var removed = false
        for dir in ["/usr/local/bin", "\(NSHomeDirectory())/.local/bin"] {
            let link = "\(dir)/boopa"
            if FileManager.default.fileExists(atPath: link) {
                try? FileManager.default.removeItem(atPath: link)
                print("Removed: \(link)")
                removed = true
            }
        }
        if !removed { print("No `boopa` symlink found.") }
    }
}

struct Quit: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Quit the Boopa agent.")

    func run() throws {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Agent.bundleID)
            .filter { $0.processIdentifier != getpid() }
        if others.isEmpty { print("Agent not running."); return }
        others.forEach { $0.terminate() }
        print("Quit Boopa agent.")
    }
}

// MARK: - Agent discovery / IPC

enum Agent {
    static let bundleID = "com.eilgnaw.boopa"

    static func isRunning() -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != getpid() }
    }

    /// The enclosing `Boopa.app`, resolving the symlink the CLI may have been launched through.
    static func appURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" { return bundleURL }
        var url = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .resolvingSymlinksInPath()
        while url.path != "/" {
            if url.pathExtension == "app" { return url }
            url.deleteLastPathComponent()
        }
        return nil
    }

    static func ensureRunningThenSend(_ command: WireCommand) {
        if isRunning() {
            send(command)
            return
        }
        guard let url = appURL() else {
            FileHandle.standardError.write(Data(
                "boopa: agent app not found. Launch Boopa.app once, or run `boopa install` from the built app.\n".utf8))
            send(command) // best effort
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        let sem = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in sem.signal() }
        _ = sem.wait(timeout: .now() + 5)
        Thread.sleep(forTimeInterval: 0.4) // let the agent register its observer
        send(command)
    }

    static func send(_ command: WireCommand) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(WireCommand.notificationName),
            object: nil,
            userInfo: [WireCommand.userInfoKey: command.jsonString() ?? ""],
            deliverImmediately: true
        )
    }
}
