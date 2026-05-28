import AppKit
import SwiftUI

/// A small settings window hosting the Clear-on-Focus checklist. Menus close on every
/// click, which makes multi-select painful — a window lets you toggle many apps freely.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?
    private let model = ClearOnFocusModel()

    func show(onChange: @escaping (Set<String>) -> Void) {
        model.onChange = onChange
        model.reload() // refresh selection + running-app list every time it opens

        if window == nil {
            let hosting = NSHostingController(rootView: ClearOnFocusSettingsView(model: model))
            let w = NSWindow(contentViewController: hosting)
            w.title = String(localized: "Boopa Settings")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct AppRow: Identifiable {
    let id: String // bundle identifier
    let name: String
    let icon: NSImage?
    let running: Bool
}

/// In-memory source of truth for the checklist. Toggling mutates `selected` (which drives
/// the UI immediately) and persists to disk — it never re-reads the file mid-toggle, so the
/// view can't get clobbered. The file is only re-read on open / Refresh.
@MainActor
@Observable
final class ClearOnFocusModel {
    var selected: Set<String> = []
    var apps: [AppRow] = []
    @ObservationIgnored var onChange: ((Set<String>) -> Void)?

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        onChange?(selected)
    }

    func reload() {
        let config = BoopaConfig.load()
        selected = Set(config.clearOnFocus)

        var rows: [String: AppRow] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier, id != Agent.bundleID else { continue }
            rows[id] = AppRow(id: id, name: app.localizedName ?? id, icon: app.icon, running: true)
        }
        for id in selected where rows[id] == nil {
            rows[id] = AppRow(id: id, name: id, icon: nil, running: false)
        }
        apps = rows.values.sorted { lhs, rhs in
            if lhs.running != rhs.running { return lhs.running }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private struct ClearOnFocusSettingsView: View {
    let model: ClearOnFocusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focusing one of these clears a persistent glow")
                .font(.headline)

            List {
                ForEach(model.apps) { app in
                    Toggle(isOn: Binding(
                        get: { model.selected.contains(app.id) },
                        set: { _ in model.toggle(app.id) }
                    )) {
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "app.dashed").frame(width: 18, height: 18)
                            }
                            Text(app.name)
                            if !app.running {
                                Text("not running").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            HStack {
                Button("Edit config file…") {
                    BoopaConfig.writeSampleConfigIfMissing()
                    NSWorkspace.shared.open(BoopaConfig.configURL)
                }
                Spacer()
                Button("Refresh") { model.reload() }
            }

            Link("Source Code", destination: BoopaLinks.repo)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 380, height: 460)
    }
}
