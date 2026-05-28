# Boopa + Cursor (and other agents)

Cursor doesn't expose lifecycle hooks the way Claude Code does, so the simplest integration is
to have the agent run `boopa` as a shell command — either by asking it to, via a project rule,
or by wrapping long-running tasks.

## 1. Project rule

Add a rule (`.cursor/rules/boopa.md` or Settings → Rules) such as:

> When you finish a task or need my input, run `boopa attention` in the terminal.
> When I reply, run `boopa clear`.

## 2. Wrap long-running commands

Use the generic wrapper ([`generic.sh`](./generic.sh)) so any command flashes on completion:

```bash
boopa-run npm run build      # green flash on success, orange on failure
boopa-run pytest             # glow when the suite finishes
```

## 3. Call it directly from any tool

Boopa is a plain CLI, so anything that can run a shell command can drive it:

```bash
boopa attention --theme attention   # persistent glow
boopa flash --theme success         # one-shot
boopa clear                         # dismiss
```

Focus-clear still applies: switching back to an app listed in `clear_on_focus`
(`~/.config/boopa/config.toml`) dismisses a persistent glow automatically.
