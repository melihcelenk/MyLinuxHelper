#!/usr/bin/env bash
# setup.sh — Symlink commands into ~/.local/bin (no aliases), then re-exec login shell.
# Optional: set MLH_INSTALL_USR_LOCAL=1 to also link into /usr/local/bin (needs sudo).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$ROOT_DIR/plugins"
LOCAL_BIN="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

# 1) Ensure ~/.local/bin exists and added to PATH for future shells
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
  ["$LOCAL_BIN/linux"]="$PLUGINS_DIR/linux.sh"
  ["$LOCAL_BIN/mlh"]="$PLUGINS_DIR/mlh.sh"
  ["$LOCAL_BIN/search"]="$PLUGINS_DIR/search.sh"
)

for link in "${!LINKS[@]}"; do
  target="${LINKS[$link]}"
  rm -f "$link"
  ln -s "$target" "$link"
  echo "Linked: $(basename "$link") → $target"
done

# 4) (Optional) /usr/local/bin fallback — only if explicitly requested
if [ "${MLH_INSTALL_USR_LOCAL:-0}" = "1" ] && command -v sudo >/dev/null 2>&1; then
  echo "Linking into /usr/local/bin (requested via MLH_INSTALL_USR_LOCAL=1)..."
  declare -A ULINKS=(
    ["/usr/local/bin/i"]="$ROOT_DIR/install.sh"
    ["/usr/local/bin/isjsonvalid"]="$PLUGINS_DIR/isjsonvalid.sh"
    ["/usr/local/bin/ll"]="$PLUGINS_DIR/ll.sh"
    ["/usr/local/bin/linux"]="$PLUGINS_DIR/linux.sh"
    ["/usr/local/bin/mlh"]="$PLUGINS_DIR/mlh.sh"
    ["/usr/local/bin/search"]="$PLUGINS_DIR/search.sh"
  )
  for link in "${!ULINKS[@]}"; do
    target="${ULINKS[$link]}"
    sudo rm -f "$link" 2>/dev/null || true
    sudo ln -s "$target" "$link" 2>/dev/null || true
  done
fi

# 5) If current session still can't see commands, re-exec a fresh login shell
need_reload=0
for bin in i isjsonvalid ll linux mlh search; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    need_reload=1; break
  fi
done

echo "✅ Setup complete. Commands: i, isjsonvalid, ll, linux, mlh, search"
echo ""
echo "Examples:"
echo "  linux mycontainer           # Create ephemeral container (default)"
echo "  linux -p mycontainer        # Create permanent container"
echo "  linux -s mycontainer        # Stop container"
echo ""
echo "  mlh docker in mycontainer   # Enter running container by name pattern"
echo "  search myfile               # Search for files in current directory"
echo "  i nginx                     # Install package using system package manager"
echo "  isjsonvalid data.json       # Validate JSON file"
echo "  ll /var/log                 # List directory contents with details"

if [ "$need_reload" -eq 1 ] && [ -t 1 ] && [ -z "${MLH_RELOADED:-}" ]; then
  echo "↻ Opening a fresh login shell so commands are available immediately..."
  export MLH_RELOADED=1
  exec "${SHELL:-/bin/bash}" -l
fi
