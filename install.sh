#!/usr/bin/env bash
# Links every skill in skills/ (and the agents it ships) into Claude Code's config, so edits here take effect at once.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd -P)"
home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$home/skills" "$home/agents"

# A dangling link into this repo, or into a clone of it that moved (same layout: .../skills/<name> or
# .../skills/<name>/agents/<file>), is ours: its skill or agent was renamed, removed or moved.
ours_dangling() {
  local dst="$1" target
  [ -L "$dst" ] && [ ! -e "$dst" ] || return 1
  target="$(readlink "$dst")"
  [[ "$target" == "$repo"/* || "$target" == */skills/"$(basename "$dst")" ||
     "$target" == */skills/*/agents/"$(basename "$dst")" ]]
}
for dst in "$home"/skills/* "$home"/agents/*; do
  if ours_dangling "$dst"; then
    rm "$dst"
    echo "removed stale $dst"
  fi
done

skipped=0
link() {
  local src="$1" dst="$2"
  # Ours to replace: a link into this repo, or one that already resolves to the same file.
  if [ -L "$dst" ] && { [[ "$(readlink "$dst")" == "$repo"/* ]] || [ "$dst" -ef "$src" ]; }; then
    rm "$dst"
  elif [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "skip: $dst exists and is not one of this repo's links; move it away and rerun" >&2
    skipped=1
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
exit "$skipped"
