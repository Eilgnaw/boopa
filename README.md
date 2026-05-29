# Boopa

[English](README.md) | [简体中文](README.zh-CN.md)

Boopa flashes a glowing ring around your screen edges to tell you an AI agent needs
your attention — and ships a `boopa` CLI so agents can trigger it straight from their
hooks. When you've wandered off while Claude Code or Cursor grinds through a task, the
edges breathe red until you come back; switch focus to your terminal and the glow clears
itself.

It runs as a tiny menu-bar app (no Dock icon) with a matching command-line tool baked
into the same binary.

## Screenshots

| Screen-edge glow | Notch traffic light |
| :---: | :---: |
| ![Screen-edge glow mode](docs/images/glow.png) | ![Notch traffic-light mode](docs/images/traffic-light.png) |

## Features

- **Screen-edge glow** on every display — a transparent, click-through overlay that
  paints only the edges, so it never blocks what's underneath.
- **Two glow modes**: a one-shot `flash` that fades out, and a persistent `attention`
  beacon that stays until dismissed.
- **Traffic-light beacon**: `boopa light <red|yellow|green …>` slides a horizontal
  traffic light down out of the notch (or the screen's top-center when there's no notch).
  A glanceable status signal — e.g. green = done, red = blocked, yellow = working — that
  you pick the lit lamps for. Independent of the edge glow; the two never interfere.
- **Clear on focus**: switching to your terminal/editor auto-dismisses the glow — you're
  already looking, so it stops nagging.
- **Themes & animations**: `breathe`, `pulse`, `comet`, `blink`, `solid`; tune color,
  edges, thickness, blur, intensity, and speed per theme or per call.
- **CLI-first**: drive everything from the shell, ideal for agent hooks. The CLI
  auto-launches the agent if it isn't running.
- **Menu-bar settings**: a Clear-on-Focus picker and Launch-at-Login toggle.
- **Localized**: English and Simplified Chinese.

## Install

### Homebrew (recommended)

```bash
brew install --cask Eilgnaw/tap/boopa
```

The cask installs `Boopa.app` and puts the `boopa` CLI on your PATH. The released app is
signed with a Developer ID and notarized by Apple, so it opens without Gatekeeper
warnings.

### Build from source

Requires macOS 15+, Xcode, and [mise](https://mise.jdx.dev).

```bash
git clone https://github.com/Eilgnaw/boopa.git
cd boopa
make setup          # installs Tuist via mise, resolves deps, generates the project
open Boopa.xcworkspace   # then Run (⌘R)
```

Once it's running, link the CLI onto your PATH:

```bash
"$(mdfind -name Boopa.app | head -1)/Contents/MacOS/Boopa" install
# or, from inside Xcode's build products, run:  Boopa install
```

## Usage

```bash
boopa attention                       # persistent glow until cleared
boopa flash                           # one-shot pulse that fades out
boopa clear                           # dismiss any active glow

boopa flash --color blue --edges top  # blue, top edge only
boopa attention --theme warn          # use a named theme from your config
boopa flash --animation comet --speed 2 --duration 4
```

Style flags (override the chosen theme): `--theme --color --edges --thickness --blur
--animation --speed --intensity --duration`.

### Traffic-light beacon

A horizontal red/yellow/green light that drops out of the notch; pass the lamps to light
(default `red`). It stays until `boopa clear` unless you give it a duration.

```bash
boopa light green                     # all-clear / done
boopa light red                       # blocked / needs you
boopa light yellow                    # working / thinking
boopa light red yellow                # light two lamps at once
boopa light green --oneshot --duration 3   # fade out on its own
boopa light red --size 220            # override the bar width (defaults to the notch)
```

Flags: `--size` (bar width in points; defaults to the notch width), `--duration`,
`--oneshot`. Dismiss with `boopa clear` (same command that clears the glow).

Management commands:

```bash
boopa themes        # list configured themes
boopa status        # is the agent running? which config / clear_on_focus?
boopa install       # symlink boopa onto your PATH
boopa uninstall     # remove the symlink
boopa quit          # quit the agent
```

You don't need to start the app first — `flash`/`attention` launch the menu-bar agent on
demand. Enable **Launch at Login** from the menu bar for zero startup latency.

## Configuration

Config lives at `~/.config/boopa/config.toml` (a starter file is written on first
`install`):

```toml
default_theme = "attention"
auto_clear_seconds = 0       # persistent-glow fallback timeout; 0 = never

# Focusing one of these apps clears a persistent glow.
clear_on_focus = [
  "com.googlecode.iterm2",
  "com.microsoft.VSCode",
]

[themes.attention]
color     = "#FF3B30"   # hex, or a name like red / green / blue
edges     = ["all"]     # all | top | bottom | left | right
thickness = 6.0
blur      = 24.0
animation = "breathe"   # breathe | pulse | comet | blink | solid
speed     = 1.0         # cycles per second
intensity = 0.9         # 0..1
mode      = "persistent"
flashes   = 3

[themes.success]
color = "#34C759"
animation = "pulse"
mode = "oneshot"
flashes = 2
```

Find an app's bundle id with `osascript -e 'id of app "Terminal"'`. You can also manage
the **Clear on Focus** list from the menu-bar **Clear on Focus…** window — toggle apps
with checkboxes; changes save instantly.

## Agent integration

Boopa is a neutral CLI, so anything that runs shell commands can drive it. See
[`examples/`](examples/):

- [`examples/claude-code.md`](examples/claude-code.md) — wire `boopa` into Claude Code
  hooks (`Notification` → glow, `Stop` → flash, `UserPromptSubmit` → clear).
- [`examples/cursor.md`](examples/cursor.md) — Cursor and rule-based setups.
- [`examples/generic.sh`](examples/generic.sh) — `boopa-run <cmd>` flashes green/orange
  when any command finishes.

Quick Claude Code setup (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Notification": [{ "hooks": [{ "type": "command", "command": "boopa attention" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "boopa flash --theme success" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "boopa clear" }] }]
  }
}
```

## Development

Boopa uses [Tuist](https://tuist.dev) (pinned via mise) to generate the Xcode project;
the `.xcodeproj` is not committed.

```bash
make setup      # install tools, resolve deps, generate the project
make generate   # regenerate after editing Project.swift
make clean      # clean Tuist artifacts
```

## Links

- **[Linux.do](https://linux.do)**
