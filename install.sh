#!/usr/bin/env bash
# Links every skill in skills/ (and the agents it ships) into Claude Code's config, so edits here take effect at once.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$home/skills" "$home/agents"

link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    echo "skip: $dst exists and is not a link; move it away and rerun" >&2
    return
  fi
  ln -s "$src" "$dst"
  echo "linked $dst"
}

for skill in "$repo"/skills/*/; do
  name="$(basename "$skill")"
  link "${skill%/}" "$home/skills/$name"
  for agent in "$skill"agents/*.md; do
    [ -e "$agent" ] || continue
    link "$agent" "$home/agents/$(basename "$agent")"
  done
done
