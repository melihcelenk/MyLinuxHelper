#!/bin/bash
# setup.sh — Registers plugin commands and ensures "i" function is loaded safely.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$ROOT_DIR/plugins"
BASHRC="$HOME/.bashrc"

# 1) Make plugin scripts executable (user only gives exec to setup.sh)
echo "Granting execute permission to all plugin scripts..."
find "$PLUGINS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

# 2) Clean up any old 'i' alias to avoid recursion
if grep -qE '^[[:space:]]*alias[[:space:]]+i=' "$BASHRC" 2>/dev/null; then
  # Remove all alias i=... lines
  sed -i '/^[[:space:]]*alias[[:space:]]\+i=/d' "$BASHRC"
  echo "Removed old alias 'i' from ~/.bashrc"
fi

# 3) Insert a guarded block that sources install.sh and ensures function i exists
START_MARK='# >>> hevi-plugins i loader >>>'
END_MARK='# <<< hevi-plugins i loader <<<'
# Remove previous block if exists
if grep -Fq "$START_MARK" "$BASHRC" 2>/dev/null; then
  awk -v s="$START_MARK" -v e="$END_MARK" '
    $0==s {skip=1}
    !skip {print}
    $0==e {skip=0}
  ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi

# Append fresh loader block
cat >> "$BASHRC" <<EOF

$START_MARK
# Ensure 'i' is a function loaded from install.sh (no alias recursion).
unalias i 2>/dev/null
if ! declare -F i >/dev/null; then
  if [ -f "$ROOT_DIR/install.sh" ]; then
    . "$ROOT_DIR/install.sh"
  fi
fi
$END_MARK
EOF

# 4) Register plugin command aliases
assignments=(
  "isjsonvalid plugins/isjsonvalid.sh"
  "ll plugins/ll.sh"
)

for mapping in "${assignments[@]}"; do
  commandName=$(echo "$mapping" | awk '{print $1}')
  relativeScriptPath=$(echo "$mapping" | awk '{print $2}')
  absoluteScriptPath="$ROOT_DIR/$relativeScriptPath"

  # Remove stale alias lines for this command (idempotent)
  sed -i "/^[[:space:]]*alias[[:space:]]\+$commandName=/d" "$BASHRC"

  # Add alias
  echo "alias $commandName='bash \"$absoluteScriptPath\"'" >> "$BASHRC"
  echo "Registered: $commandName → $absoluteScriptPath"
done

# 5) Load into current session without closing the terminal
# shellcheck source=/dev/null
. "$BASHRC"

echo "✅ Setup complete. Try now:"
echo "   i net-tools"
echo "   isjsonvalid data.json"
echo "   ll /etc"
