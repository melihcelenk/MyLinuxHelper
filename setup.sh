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
grep -Fq "$ADD_LINE" "$BASHRC" 2>/dev/null || {
	echo "$ADD_LINE" >>"$BASHRC"
	echo "Added ~/.local/bin to PATH in ~/.bashrc"
}
grep -Fq "$ADD_LINE" "$PROFILE" 2>/dev/null || {
	echo "$ADD_LINE" >>"$PROFILE"
	echo "Added ~/.local/bin to PATH in ~/.profile"
}

# 1b) Add mlh wrapper function to ensure current session history is visible
MLH_WRAPPER_MARKER="# MyLinuxHelper - mlh wrapper function"
if ! grep -Fq "$MLH_WRAPPER_MARKER" "$BASHRC" 2>/dev/null; then
	cat >>"$BASHRC" <<'EOF'

# MyLinuxHelper - mlh wrapper function
# This wrapper ensures current session history is visible to mlh history command
mlh() {
  # If using mlh history, save current session history first
  if [ "$1" = "history" ]; then
    history -a 2>/dev/null || true
  fi
  # Call the actual mlh script
  command mlh "$@"
}

# MyLinuxHelper - bookmark wrapper function
# This wrapper enables 'cd' functionality by evaluating the output
bookmark() {
  local cmd="$1"
  shift
  
  # For jumping to bookmarks (number or name), eval the output to enable cd
  if [[ "$cmd" =~ ^[0-9]+$ ]] || [ -n "$cmd" ] && [ "$cmd" != "." ] && [ "$cmd" != "list" ] && [ "$cmd" != "mv" ] && [ "$cmd" != "--help" ] && [ "$cmd" != "-h" ] && [ "$cmd" != "--version" ] && [ "$cmd" != "-v" ]; then
    # This might be a bookmark name/number - check if it produces a cd command
    local output
    output=$(command bookmark "$cmd" "$@" 2>&1)
    if echo "$output" | grep -q "^cd "; then
      # Extract and execute the cd command
      eval "$(echo "$output" | grep "^cd ")"
      # Show the rest of the output (without the cd line)
      echo "$output" | grep -v "^cd " >&2
    else
      # Not a jump command, just show the output
      echo "$output"
      return $?
    fi
  else
    # For other commands (save, list, mv, help), just pass through
    command bookmark "$cmd" "$@"
  fi
}
EOF
	echo "Added mlh wrapper function to ~/.bashrc"
fi

# 2) Make scripts executable
echo "Granting execute permission to all plugin scripts..."
find "$PLUGINS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
chmod +x "$ROOT_DIR/install.sh"

# 3) Create/refresh symlinks in ~/.local/bin
declare -A LINKS=(
	["$LOCAL_BIN/bookmark"]="$PLUGINS_DIR/mlh-bookmark.sh"
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
		["/usr/local/bin/bookmark"]="$PLUGINS_DIR/mlh-bookmark.sh"
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
		need_reload=1
		break
	fi
done

echo "✅ Setup complete. Commands: i, isjsonvalid, ll, linux, mlh, search"
echo ""
echo "Examples:"
echo "  linux mycontainer                    # Create ephemeral container (default)"
echo "  linux -p mycontainer                 # Create permanent container"
echo "  linux -s mycontainer                 # Stop container"
echo ""
echo "  mlh docker in mycontainer            # Enter running container by name pattern"
echo "  mlh history                          # Show command history (numbered)"
echo "  mlh history 10                       # Show last 10 commands"
echo "  search myfile                        # Search for files in current directory"
echo "  i nginx                              # Install package using system package manager"
echo ""
echo "  isjsonvalid data.json                # Quick JSON validation (Yes/No)"
echo "  isjsonvalid -d data.json             # Detailed JSON validation"
echo "  mlh json --isvalid data.json         # Detailed JSON validation"
echo "  mlh json get name from users.json    # Search JSON with fuzzy matching"
echo ""
echo "  ll /var/log                          # List directory contents with details"

if [ "$need_reload" -eq 1 ] && [ -t 1 ] && [ -z "${MLH_RELOADED:-}" ]; then
	echo "↻ Opening a fresh login shell so commands are available immediately..."
	export MLH_RELOADED=1
	exec "${SHELL:-/bin/bash}" -l
fi
