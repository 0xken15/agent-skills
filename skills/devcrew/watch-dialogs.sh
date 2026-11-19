#!/usr/bin/env bash
# Waits until a child session's screen shows a dialog waiting on an answer (a permission prompt, a trust, mode or MCP
# dialog), then prints "<handle> <sum>" and exits 0. Run it as a background command: it costs no tokens while it
# waits, and its exit wakes the orchestrator only when there is something to look at.
#   bash watch-dialogs.sh <state-file> <terminal-handle>...   watch these terminals
#   bash watch-dialogs.sh <state-file> --answered <handle>    forget that terminal's last dialog once it is answered
# A terminal it cannot read (a stale handle, orca missing) makes it print "stale <handle>" and exit 3.
set -u

if [ "$#" -lt 2 ]; then
  echo "usage: bash watch-dialogs.sh <state-file> <terminal-handle>... | <state-file> --answered <handle>" >&2
  exit 2
fi
state="$1"
shift
touch "$state"

if [ "$1" = "--answered" ]; then
  grep -v "^${2:?handle} " "$state" >"$state.tmp" || true
  mv "$state.tmp" "$state"
  exit 0
fi

# The words Claude Code's dialogs show; the board run reads the screens too, for anything this misses.
pattern='Do you want|Would you like to proceed|Yes, I (accept|trust)|New MCP server found'

while :; do
  for handle in "$@"; do
    if ! screen="$(orca terminal read --screen --terminal "$handle" --limit 30 2>/dev/null)"; then
      echo "stale $handle"
      exit 3
    fi
    # Only the dialog's own lines count (the matched line and the numbered option lines after it), so a spinner or a
    # timer on the screen does not make text that only looks like a dialog fire again on every read.
    block="$(printf '%s\n' "$screen" | awk -v p="$pattern" '
      $0 ~ p { seen = 1; print; next }
      seen && /^[[:space:]]*(❯[[:space:]]*)?[0-9]+\. / { print }')"
    [ -n "$block" ] || continue
    sum="$(printf '%s' "$block" | cksum | cut -d' ' -f1)"
    grep -qx "$handle $sum" "$state" && continue
    echo "$handle $sum" >>"$state"
    echo "$handle $sum"
    exit 0
  done
  sleep 20
done
