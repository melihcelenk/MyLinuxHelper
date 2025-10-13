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

# Parse arguments
if [ $# -eq 0 ]; then
  print_help
  exit 1
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
