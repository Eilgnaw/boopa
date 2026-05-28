import AppKit

/// Single binary, two modes:
/// - invoked with a known subcommand (or a leading flag) → run as the `boopa` CLI;
/// - otherwise (double-click / login item) → run as the menu-bar agent.
@main
enum BoopaMain {
    // Retained for the lifetime of the process (NSApplication.delegate is weak).
    static var delegate: AppDelegate?

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        // Run as the CLI only for a real `boopa` invocation. Never for the system /
        // Xcode launch arguments (e.g. `-NSDocumentRevisionsDebugMode`, `-psn_…`) that
        // get injected when the app is launched normally — those start the agent.
        let helpFlags: Set<String> = ["--help", "-h", "--version"]
        let isCLI = !args.isEmpty && (
            BoopaCLI.knownSubcommands.contains(args[0])
            || helpFlags.contains(args[0])
            || isatty(STDOUT_FILENO) != 0
        )

        if isCLI {
            BoopaCLI.main(args) // parses, runs, and exits the process
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon, never steals focus
        app.run()
    }
}
