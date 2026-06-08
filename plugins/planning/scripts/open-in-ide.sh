#!/usr/bin/env bash
# Open a file in the JetBrains IDE that hosts the current terminal session.
#
# Best-effort and silent by design: it only acts when invoked from inside a
# JetBrains IDE terminal whose host IDE can be identified by walking the process
# ancestry. In any other context (plain terminal, VS Code, IDE not found, no
# /proc, etc.) it does nothing and exits 0 — it must never fail or block the
# caller. Used by /planning:make step 3 to surface a freshly created plan.

file="${1:-}"
[ -n "$file" ] || exit 0

# JetBrains terminals (both Linux and macOS) export this marker.
[ "${TERMINAL_EMULATOR:-}" = "JetBrains-JediTerm" ] || exit 0

# Known JetBrains IDE launcher/binary names (comm is <=15 chars on Linux, all fit).
known='idea phpstorm webstorm pycharm goland clion rider rubymine datagrip rustrover'

# Walk the process ancestry upward to find the IDE process that owns this terminal.
pid=$$
ide_pid=""
ide_name=""
for _ in $(seq 1 20); do
  [ -n "$pid" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ] || break
  name=$(basename "$(ps -o comm= -p "$pid" 2>/dev/null)" 2>/dev/null)
  for k in $known; do
    [ "$name" = "$k" ] && { ide_pid="$pid"; ide_name="$k"; break; }
  done
  [ -n "$ide_pid" ] && break
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done

[ -n "$ide_pid" ] || exit 0

# Resolve the exact IDE executable (Linux /proc), else fall back to the launcher on PATH.
ide_bin=$(readlink -f "/proc/$ide_pid/exe" 2>/dev/null)
[ -x "$ide_bin" ] || ide_bin=$(command -v "$ide_name" 2>/dev/null)
[ -n "$ide_bin" ] || exit 0

# Open the file in the running IDE instance; detached so it never blocks the caller.
"$ide_bin" "$file" >/dev/null 2>&1 &
exit 0
