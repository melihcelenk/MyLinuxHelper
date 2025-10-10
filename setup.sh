#!/bin/bash
# setup.sh — Install commands by creating symlinks into ~/.local/bin (no aliases)
# and re-exec a fresh login shell so commands are immediately available.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$ROOT_DIR/plugins"
LOCAL_BIN="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

# 1) Ensure ~/.local/bin exists and will be on PATH for future shells
mkdir -p "$LOCAL_BIN"
ADD_LINE='export PATH="$HOME/.local/bin:$PATH"'
grep -Fq "$ADD_LINE" "$BASHRC" 2>/dev/null || { echo "$ADD_LINE" >> "$BASHRC"; echo "Added ~/.local/bin to PATH in ~/.bashrc"; }
grep -Fq "$ADD_LINE" "$PROFILE" 2>/dev/null || { echo "$ADD_LINE" >> "$PROFILE"; echo "Added ~/.local/bin to PATH in ~/.profile"; }

# 2) Make scripts executable
echo "Granting execute permission to all plugin scripts..."
find "$PLUGINS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
chmod +x "$ROOT_DIR/install.sh"

# 3) Create/refresh symlinks in ~/.local/bin
declare -A LINKS=(
  ["$LOCAL_BIN/i"]="$ROOT_DIR/install.sh"
  ["$LOCAL_BIN/isjsonvalid"]="$PLUGINS_DIR/isjsonvalid.sh"
  ["$LOCAL_BIN/ll"]="$PLUGINS_DIR/ll.sh"
)

for link in "${!LINKS[@]}"; do
  target="${LINKS[$link]}"
  rm -f "$link"
  ln -s "$target" "$link"
  echo "Linked: $(basename "$link") → $target"
done

# 4) Optional immediate fallback into /usr/local/bin (if sudo available)
if command -v sudo >/dev/null 2>&1; then
  declare -A ULINKS=(
    ["/usr/local/bin/i"]="$ROOT_DIR/install.sh"
    ["/usr/local/bin/isjsonvalid"]="$PLUGINS_DIR/isjsonvalid.sh"
    ["/usr/local/bin/ll"]="$PLUGINS_DIR/ll.sh"
  )
  for link in "${!ULINKS[@]}"; do
    target="${ULINKS[$link]}"
    sudo rm -f "$link" 2>/dev/null || true
    sudo ln -s "$target" "$link" 2>/dev/null || true
  done
fi

# 5) If this session still can't see commands (typical in WSL),
#    seamlessly re-exec a fresh login shell (no manual 'source' needed).
need_reload=0
for bin in i isjsonvalid ll; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    need_reload=1
    break
  fi
done

echo "✅ Setup complete. Available commands: i, isjsonvalid, ll"

if [ "$need_reload" -eq 1 ] && [ -t 1 ] && [ -z "${MLH_RELOADED:-}" ]; then
  echo "↻ Opening a fresh login shell so commands are available immediately..."
  export MLH_RELOADED=1
  exec "${SHELL:-/bin/bash}" -l
fi
