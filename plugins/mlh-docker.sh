#!/usr/bin/env bash
# mlh-docker.sh — Docker shortcuts for MyLinuxHelper
#
# Usage:
#   mlh docker <command> [args...]
#   mlh docker --help
#
# Commands:
#   in <pattern>    Enter a running container by name pattern
#
# Examples:
#   mlh docker in mycontainer    # Enter container with 'mycontainer' in name

set -euo pipefail

print_help() {
  cat <<'EOF'
mlh docker - Docker shortcuts

Usage:
  mlh docker <command> [args...]
  mlh docker --help

Commands:
  in <pattern>    Enter a running container by name pattern.
                  If multiple containers match, shows interactive menu.

Examples:
  mlh docker in web           # Enter container with 'web' in name

  # If multiple containers match 'mycontainer':
  mlh docker in mycontainer

  Output:
    Multiple containers found matching 'mycontainer':

      1. mycontainer-web (nginx:latest | Up 2 hours)
      2. mycontainer-api (node:18 | Up 2 hours)
      3. mycontainer-db (postgres:14 | Up 2 hours)

    Select container [1-3]: 1

    Entering container: mycontainer-web
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

# Check if docker is available
if ! command -v docker >/dev/null 2>&1; then
  die "Docker is not installed or not in PATH"
fi

# Parse command
if [ $# -eq 0 ]; then
  print_help
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  -h|--help)
    print_help
    exit 0
    ;;
  in)
    # Enter container by pattern
    if [ $# -eq 0 ]; then
      die "Missing container name pattern. Usage: mlh docker in <pattern>"
    fi

    PATTERN="$1"

    # Find matching containers (running only)
    mapfile -t CONTAINERS < <(docker ps --format "{{.ID}}|{{.Names}}" | grep -i "$PATTERN" || true)

    if [ ${#CONTAINERS[@]} -eq 0 ]; then
      die "No running containers found matching pattern: $PATTERN"
    fi

    if [ ${#CONTAINERS[@]} -eq 1 ]; then
      # Single match - enter directly
      CONTAINER_ID="${CONTAINERS[0]%%|*}"
      CONTAINER_NAME="${CONTAINERS[0]##*|}"
      echo "Entering container: $CONTAINER_NAME"
      exec docker exec -it "$CONTAINER_ID" bash
    else
      # Multiple matches - show menu
      echo "Multiple containers found matching '$PATTERN':"
      echo ""

      for i in "${!CONTAINERS[@]}"; do
        CONTAINER_NAME="${CONTAINERS[$i]##*|}"
        CONTAINER_ID="${CONTAINERS[$i]%%|*}"
        # Get container image and status
        CONTAINER_INFO=$(docker ps --filter "id=$CONTAINER_ID" --format "{{.Image}} | {{.Status}}" | head -1)
        echo "  $((i+1)). $CONTAINER_NAME ($CONTAINER_INFO)"
      done

      echo ""
      read -rp "Select container [1-${#CONTAINERS[@]}]: " SELECTION

      # Validate selection
      if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#CONTAINERS[@]} ]; then
        die "Invalid selection: $SELECTION"
      fi

      # Enter selected container
      SELECTED_INDEX=$((SELECTION - 1))
      CONTAINER_ID="${CONTAINERS[$SELECTED_INDEX]%%|*}"
      CONTAINER_NAME="${CONTAINERS[$SELECTED_INDEX]##*|}"

      echo ""
      echo "Entering container: $CONTAINER_NAME"
      exec docker exec -it "$CONTAINER_ID" bash
    fi
    ;;
  *)
    echo "Error: Unknown command '$COMMAND'" >&2
    echo "Run 'mlh docker --help' for available commands." >&2
    exit 1
    ;;
esac
