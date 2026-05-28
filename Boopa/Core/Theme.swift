import Foundation

// MARK: - Enums

enum GlowAnimation: String, Codable, CaseIterable {
    case breathe, pulse, comet, blink, solid
}

enum GlowMode: String, Codable, CaseIterable {
    case persistent, oneshot
}

/// A single edge of the screen. `all` is expanded to the four sides at render time.
enum GlowEdge: String, Codable, CaseIterable {
    case all, top, bottom, left, right

    /// Parse a list of raw tokens, expanding `all`, deduping, ignoring unknowns.
    static func parse(_ tokens: [String]) -> Set<GlowEdge> {
        var result = Set<GlowEdge>()
        for token in tokens {
            switch GlowEdge(rawValue: token.lowercased()) {
            case .all: return [.top, .bottom, .left, .right]
            case .some(let edge): result.insert(edge)
            case .none: break
            }
        }
        return result.isEmpty ? [.top, .bottom, .left, .right] : result
    }
}

// MARK: - Theme

/// Visual description of a glow. Decodable from a `[themes.<name>]` TOML table where
/// every field is optional and missing fields fall back to the defaults below.
struct Theme: Codable, Equatable {
    var color: String = "#FF3B30"
    var edges: [String] = ["all"]
    var thickness: Double = 6
    var blur: Double = 24
    var animation: String = "breathe"
    var speed: Double = 1.0
    var intensity: Double = 0.9
    var mode: String = "persistent"
    var flashes: Int = 3

    init() {}

    init(
        color: String,
        edges: [String] = ["all"],
        thickness: Double = 6,
        blur: Double = 24,
        animation: String = "breathe",
        speed: Double = 1.0,
        intensity: Double = 0.9,
        mode: String = "persistent",
        flashes: Int = 3
    ) {
        self.color = color
        self.edges = edges
        self.thickness = thickness
        self.blur = blur
        self.animation = animation
        self.speed = speed
        self.intensity = intensity
        self.mode = mode
        self.flashes = flashes
    }

    // Decode partial tables: any missing key keeps its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var base = Theme()
        base.color = try c.decodeIfPresent(String.self, forKey: .color) ?? base.color
        base.edges = try c.decodeIfPresent([String].self, forKey: .edges) ?? base.edges
        base.thickness = try c.decodeIfPresent(Double.self, forKey: .thickness) ?? base.thickness
        base.blur = try c.decodeIfPresent(Double.self, forKey: .blur) ?? base.blur
        base.animation = try c.decodeIfPresent(String.self, forKey: .animation) ?? base.animation
        base.speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? base.speed
        base.intensity = try c.decodeIfPresent(Double.self, forKey: .intensity) ?? base.intensity
        base.mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? base.mode
        base.flashes = try c.decodeIfPresent(Int.self, forKey: .flashes) ?? base.flashes
        self = base
    }

    // Parsed accessors with safe fallbacks.
    var animationKind: GlowAnimation { GlowAnimation(rawValue: animation.lowercased()) ?? .breathe }
    var modeKind: GlowMode { GlowMode(rawValue: mode.lowercased()) ?? .persistent }
    var edgeSet: Set<GlowEdge> { GlowEdge.parse(edges) }
    var period: Double { speed > 0 ? 1.0 / speed : 1.0 }
}

// MARK: - Flag overrides

/// CLI flag overrides applied on top of a resolved theme. `nil` means "leave as-is".
struct StyleOverrides {
    var color: String?
    var edges: [String]?
    var thickness: Double?
    var blur: Double?
    var animation: String?
    var speed: Double?
    var intensity: Double?
}

extension Theme {
    func applying(_ o: StyleOverrides) -> Theme {
        var t = self
        if let v = o.color { t.color = v }
        if let v = o.edges { t.edges = v }
        if let v = o.thickness { t.thickness = v }
        if let v = o.blur { t.blur = v }
        if let v = o.animation { t.animation = v }
        if let v = o.speed { t.speed = v }
        if let v = o.intensity { t.intensity = v }
        return t
    }

    func with(mode: GlowMode) -> Theme {
        var t = self
        t.mode = mode.rawValue
        return t
    }
}

// MARK: - Built-in themes

extension Theme {
    static let builtIns: [String: Theme] = [
        "attention": Theme(color: "#FF3B30", animation: "breathe", mode: "persistent"),
        "success": Theme(color: "#34C759", animation: "pulse", mode: "oneshot", flashes: 2),
        "info": Theme(color: "#0A84FF", animation: "breathe", mode: "persistent"),
        "warn": Theme(color: "#FF9F0A", animation: "pulse", mode: "oneshot", flashes: 3),
    ]
}

// MARK: - Wire protocol (CLI ⇄ agent)

enum WireAction: String, Codable {
    case show
    case clear
}

/// The message the CLI sends to the agent over DistributedNotificationCenter.
/// The CLI resolves the full visual style; the agent owns behavioral config
/// (`clear_on_focus`, `auto_clear_seconds`) read from its own config file.
struct WireCommand: Codable {
    var action: WireAction
    var style: Theme?
    /// Optional explicit duration in seconds (overrides the computed oneshot length
    /// or sets a persistent fallback timeout for this command).
    var duration: Double?

    static let notificationName = "com.eilgnaw.boopa.command"
    static let userInfoKey = "payload"

    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func from(jsonString: String) -> WireCommand? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WireCommand.self, from: data)
    }
}
