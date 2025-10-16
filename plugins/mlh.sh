#!/usr/bin/env bash
# mlh.sh — Main dispatcher for MyLinuxHelper shortcut commands
#
# Usage:
#   mlh <category> <command> [args...]
#   mlh --help
#   mlh --version
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
  cat <<EOF
mlh - MyLinuxHelper shortcut commands

Usage:
  mlh                          Show interactive menu
  mlh <category> <command>     Run category command
  mlh --help                   Show this help
  mlh --version                Show version
  mlh update                   Update to latest version

Categories:
  docker    Docker shortcuts (see: mlh docker --help)

Examples:
  mlh                          # Show interactive menu
  mlh --version                # Show current version
  mlh update                   # Update to latest version
  mlh docker in mycontainer    # Enter a running container by name pattern
EOF
}

print_version() {
  exec "$SCRIPT_DIR/mlh-version.sh" "$@"
}

show_interactive_menu() {
  cat <<'EOF'
MyLinuxHelper - Available Commands
===================================

1. linux <name>              - Create and manage Linux containers
2. search <pattern>          - Fast file search in directories
3. i <package>               - Install packages (auto-detects package manager)
4. isjsonvalid <file.json>   - Validate JSON files
5. ll [path]                 - Enhanced directory listing (ls -la)
6. mlh docker in <pattern>   - Enter running Docker container
7. mlh --version             - Show current version
8. mlh update                - Update to latest version

Enter command number to see usage, or 'q' to quit.
EOF

  read -rp "Select [1-8, q]: " SELECTION

  echo ""

  case "$SELECTION" in
    1)
      "$SCRIPT_DIR/linux.sh" --help
      ;;
    2)
      "$SCRIPT_DIR/search.sh" --help
      ;;
    3)
      "$SCRIPT_DIR/../install.sh" --help
      ;;
    4)
      "$SCRIPT_DIR/isjsonvalid.sh" --help
      ;;
    5)
      "$SCRIPT_DIR/ll.sh" --help
      ;;
    6)
      "$SCRIPT_DIR/mlh-docker.sh" --help
      ;;
    7)
      exec "$SCRIPT_DIR/mlh-version.sh"
      ;;
    8)
      exec "$SCRIPT_DIR/mlh-version.sh" update
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
  -v|--version)
    print_version "$@"
    ;;
  update)
    # Delegate to version script for updates
    exec "$SCRIPT_DIR/mlh-version.sh" update
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
