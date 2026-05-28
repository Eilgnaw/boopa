#!/usr/bin/env bash
#
# boopa-run — run any command and glow the screen edges when it finishes.
#
#   boopa-run make build       # green one-shot flash on success
#   boopa-run pytest           # orange flash if it exits non-zero
#
# Install: copy to a directory on your PATH and `chmod +x`, e.g.
#   cp examples/generic.sh /usr/local/bin/boopa-run && chmod +x /usr/local/bin/boopa-run
#
# Requires `boopa` on your PATH (`boopa install`).

set -u

if [ "$#" -eq 0 ]; then
  echo "usage: boopa-run <command> [args...]" >&2
  exit 64
fi

"$@"
status=$?

if [ "$status" -eq 0 ]; then
  boopa flash --theme success
else
  boopa flash --theme warn
fi

exit "$status"
