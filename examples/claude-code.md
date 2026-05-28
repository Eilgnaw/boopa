# Boopa + Claude Code

Wire Boopa into [Claude Code](https://claude.ai/code) hooks so the screen glows when Claude
needs you, and clears when you get back to it.

Add to `~/.claude/settings.json` (global) or a project's `.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      { "hooks": [{ "type": "command", "command": "boopa attention" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "boopa flash --theme success" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "boopa clear" }] }
    ]
  }
}
```

What this does:

- **Notification** — Claude wants input or permission → a persistent glow until you respond.
- **Stop** — Claude finished a turn → a quick green one-shot flash.
- **UserPromptSubmit** — you sent a new message → clear the glow.

Notes:

- Run `boopa install` once so `boopa` is on your `PATH`. If hooks can't find it, use the
  absolute path (`/usr/local/bin/boopa`) in the commands above.
- Focus-clear also works automatically: switching to your terminal (or any app in
  `clear_on_focus` in `~/.config/boopa/config.toml`) dismisses a persistent glow, so the
  `UserPromptSubmit` hook is optional.
- Customize per event, e.g. `boopa attention --theme attention --color "#FF3B30"` or
  `boopa flash --theme warn` for failures.
