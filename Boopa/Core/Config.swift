import Foundation
import TOMLKit

enum BoopaLinks {
    static let repo = URL(string: "https://github.com/Eilgnaw/boopa")!
}

/// Resolved Boopa configuration: built-in defaults merged with the user's
/// `~/.config/boopa/config.toml` (file values win).
struct BoopaConfig {
    var defaultTheme: String
    var autoClearSeconds: Double
    var clearOnFocus: [String]
    var themes: [String: Theme]

    static let defaultClearOnFocus = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.microsoft.VSCode",
    ]

    /// Defaults used when no config file exists.
    static var builtInDefaults: BoopaConfig {
        BoopaConfig(
            defaultTheme: "attention",
            autoClearSeconds: 0,
            clearOnFocus: defaultClearOnFocus,
            themes: Theme.builtIns
        )
    }

    /// Look up a theme by name, falling back to the default theme, then to a hardcoded attention theme.
    func theme(named name: String?) -> Theme {
        if let name, let t = themes[name] { return t }
        if let t = themes[defaultTheme] { return t }
        return Theme.builtIns["attention"] ?? Theme()
    }

    var themeNames: [String] { themes.keys.sorted() }
}

// MARK: - Loading

extension BoopaConfig {
    /// `$XDG_CONFIG_HOME/boopa/config.toml`, else `~/.config/boopa/config.toml`.
    static var configURL: URL {
        let env = ProcessInfo.processInfo.environment
        let base: URL
        if let xdg = env["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg, isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        return base.appendingPathComponent("boopa/config.toml")
    }

    /// Load and merge the user config. Never throws — falls back to defaults on any error.
    /// Parses the TOML table by hand (rather than strict Codable) so that a number written
    /// as an integer (e.g. `auto_clear_seconds = 0`) doesn't fail the whole decode.
    static func load() -> BoopaConfig {
        var config = builtInDefaults
        guard let text = try? String(contentsOf: configURL, encoding: .utf8),
              let table = try? TOMLTable(string: text)
        else {
            return config
        }

        if let v = table["default_theme"]?.string { config.defaultTheme = v }
        if let v = table["auto_clear_seconds"] { config.autoClearSeconds = double(v) ?? config.autoClearSeconds }
        if let arr = table["clear_on_focus"]?.array {
            config.clearOnFocus = arr.compactMap { $0.string }
        }
        if let themes = table["themes"]?.table {
            for name in themes.keys {
                if let t = themes[name]?.table { config.themes[name] = theme(from: t) }
            }
        }
        return config
    }

    /// Accept either a TOML float or integer as a Double.
    private static func double(_ v: TOMLValueConvertible) -> Double? {
        v.double ?? v.int.map(Double.init)
    }

    private static func theme(from t: TOMLTable) -> Theme {
        var theme = Theme()
        if let v = t["color"]?.string { theme.color = v }
        if let v = t["edges"]?.array { theme.edges = v.compactMap { $0.string } }
        if let v = t["thickness"], let d = double(v) { theme.thickness = d }
        if let v = t["blur"], let d = double(v) { theme.blur = d }
        if let v = t["animation"]?.string { theme.animation = v }
        if let v = t["speed"], let d = double(v) { theme.speed = d }
        if let v = t["intensity"], let d = double(v) { theme.intensity = d }
        if let v = t["mode"]?.string { theme.mode = v }
        if let v = t["flashes"], let d = double(v) { theme.flashes = Int(d) }
        return theme
    }
}

// MARK: - Writing clear_on_focus

extension BoopaConfig {
    /// Rewrite only the `clear_on_focus` array in the config file, preserving comments and
    /// everything else (themes etc.) via a targeted text replacement.
    static func updateClearOnFocus(_ ids: [String]) {
        let url = configURL
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? sampleTOML

        let body = ids.map { "  \"\($0)\"," }.joined(separator: "\n")
        let literal = ids.isEmpty ? "clear_on_focus = []" : "clear_on_focus = [\n\(body)\n]"

        if let regex = try? NSRegularExpression(
            pattern: #"clear_on_focus\s*=\s*\[[^\]]*\]"#,
            options: [.dotMatchesLineSeparators]
        ) {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                text = regex.stringByReplacingMatches(
                    in: text, range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: literal))
            } else {
                text += "\n\n\(literal)\n"
            }
        }

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Sample config

extension BoopaConfig {
    /// Write a commented starter config if none exists. Returns the path written, or nil if it already existed.
    @discardableResult
    static func writeSampleConfigIfMissing() -> URL? {
        let url = configURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return nil }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? sampleTOML.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url
    }

    static let sampleTOML = """
    # Boopa configuration — https://github.com/Eilgnaw/boopa
    default_theme = "attention"

    # Persistent-glow fallback: auto-clear after N seconds. 0 = never.
    auto_clear_seconds = 0

    # Switching focus to one of these apps (bundle id) clears a persistent glow.
    # Find a bundle id with:  osascript -e 'id of app "Terminal"'
    clear_on_focus = [
      "com.apple.Terminal",
      "com.googlecode.iterm2",
      "com.mitchellh.ghostty",
      "dev.warp.Warp-Stable",
      "net.kovidgoyal.kitty",
      "com.github.wez.wezterm",
      "com.microsoft.VSCode",
    ]

    [themes.attention]
    color     = "#FF3B30"   # hex or a named color (red, green, blue, orange, …)
    edges     = ["all"]     # all | top | bottom | left | right
    thickness = 6.0         # glow band width (pt)
    blur      = 24.0        # softness
    animation = "breathe"   # breathe | pulse | comet | blink | solid
    speed     = 1.0         # cycles per second
    intensity = 0.9         # 0..1 brightness/opacity
    mode      = "persistent"
    flashes   = 3           # pulse count when used one-shot

    [themes.success]
    color = "#34C759"
    animation = "pulse"
    mode = "oneshot"
    flashes = 2
    """
}
