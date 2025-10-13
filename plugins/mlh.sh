#!/usr/bin/env bash
# mlh.sh — Main dispatcher for MyLinuxHelper shortcut commands
#
# Usage:
#   mlh <category> <command> [args...]
#   mlh --help
#
# Categories:
#   docker    Docker shortcuts (see: mlh docker --help)
#
# Examples:
#   mlh docker in mycontainer

set -euo pipefail

# Resolve script directory (handle symlinks)
resolve_script_dir() {
  local source="$0"
  while [ -L "$source" ]; do
    local target
    target="$(readlink "$source")"
    if [[ "$target" = /* ]]; then
      source="$target"
    else
      local dir
      dir="$(cd -P "$(dirname "$source")" && pwd)"
      source="$dir/$target"
    fi
  done
  cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"

print_help() {
  cat <<'EOF'
mlh - MyLinuxHelper shortcut commands

Usage:
  mlh <category> <command> [args...]
  mlh --help

Categories:
  docker    Docker shortcuts (see: mlh docker --help)

Examples:
  mlh docker in mycontainer    # Enter a running container by name pattern
EOF
}

show_interactive_menu() {
  cat <<'EOF'
MyLinuxHelper - Available Commands
===================================

1. linux <name>              - Create and manage Linux containers
2. i <package>               - Install packages (auto-detects package manager)
3. isjsonvalid <file.json>   - Validate JSON files
4. ll [path]                 - Enhanced directory listing (ls -la)
5. mlh docker in <pattern>   - Enter running Docker container

Enter command number to see usage, or 'q' to quit.
EOF

  read -rp "Select [1-5, q]: " SELECTION

  echo ""

  case "$SELECTION" in
    1)
      "$SCRIPT_DIR/linux.sh" --help
      ;;
    2)
      "$SCRIPT_DIR/../install.sh" --help
      ;;
    3)
      "$SCRIPT_DIR/isjsonvalid.sh" --help
      ;;
    4)
      "$SCRIPT_DIR/ll.sh" --help
      ;;
    5)
      "$SCRIPT_DIR/mlh-docker.sh" --help
      ;;
    q|Q)
      echo "Goodbye!"
      exit 0
      ;;
    *)
      echo "Invalid selection: $SELECTION"
      exit 1
      ;;
  esac
}

# Parse arguments
if [ $# -eq 0 ]; then
  show_interactive_menu
  exit 0
fi

CATEGORY="$1"
shift

case "$CATEGORY" in
  -h|--help)
    print_help
    exit 0
    ;;
  docker)
    # Delegate to mlh-docker.sh
    exec "$SCRIPT_DIR/mlh-docker.sh" "$@"
    ;;
  *)
    echo "Error: Unknown category '$CATEGORY'" >&2
    echo "Run 'mlh --help' for available categories." >&2
    exit 1
    ;;
esac
