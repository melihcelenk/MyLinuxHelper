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

# Parse command (check for help BEFORE checking docker availability)
if [ $# -eq 0 ]; then
	print_help
	exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
-h | --help)
	print_help
	exit 0
	;;
in)
	# Check if docker is available (only for actual commands)
	# Try to find docker in common locations if not in PATH (for sudo usage)
	DOCKER_BIN=""
	USE_SUDO=0

	if command -v docker >/dev/null 2>&1; then
		DOCKER_BIN="docker"
	elif [ -x "/usr/bin/docker" ]; then
		DOCKER_BIN="/usr/bin/docker"
	elif [ -x "/usr/local/bin/docker" ]; then
		DOCKER_BIN="/usr/local/bin/docker"
	else
		die "Docker is not installed or not in PATH"
	fi

	# Enter container by pattern
	if [ $# -eq 0 ]; then
		die "Missing container name pattern. Usage: mlh docker in <pattern>"
	fi

	PATTERN="$1"

	# Helper function to run docker command (with or without sudo)
	run_docker() {
		if [ "$USE_SUDO" -eq 1 ]; then
			sudo "$DOCKER_BIN" "$@"
		else
			"$DOCKER_BIN" "$@"
		fi
	}

	# Test Docker access and determine if sudo is needed
	# First, try without sudo
	DOCKER_TEST_OUTPUT=$("$DOCKER_BIN" ps --format "{{.ID}}" 2>&1)
	DOCKER_TEST_EXIT=$?

	if [ $DOCKER_TEST_EXIT -ne 0 ]; then
		# Docker command failed - check if it's a permission/connection error
		# Common error patterns: permission denied, cannot connect, permission denied while trying to connect
		if echo "$DOCKER_TEST_OUTPUT" | grep -qiE "permission denied|cannot connect to the docker daemon|Got permission denied|permission denied while trying to connect"; then
			# Permission/connection error - try with sudo
			if command -v sudo >/dev/null 2>&1; then
				# Test if sudo docker works
				SUDO_TEST_OUTPUT=$(sudo "$DOCKER_BIN" ps --format "{{.ID}}" 2>&1)
				SUDO_TEST_EXIT=$?
				if [ $SUDO_TEST_EXIT -eq 0 ]; then
					USE_SUDO=1
				else
					# Sudo also failed - show the error
					die "Cannot access Docker daemon even with sudo. Error: $SUDO_TEST_OUTPUT"
				fi
			else
				die "Docker requires sudo permissions but sudo is not available. Install sudo or add user to docker group. Original error: $DOCKER_TEST_OUTPUT"
			fi
		else
			# Other error (not permission related) - could be daemon not running, etc.
			die "Docker command failed: $DOCKER_TEST_OUTPUT"
		fi
	fi

	# Find matching containers (running only)
	CONTAINERS_OUTPUT=$(run_docker ps --format "{{.ID}}|{{.Names}}" 2>&1)
	CONTAINERS_EXIT=$?

	if [ $CONTAINERS_EXIT -ne 0 ]; then
		die "Failed to list Docker containers: $CONTAINERS_OUTPUT"
	fi

	mapfile -t CONTAINERS < <(echo "$CONTAINERS_OUTPUT" | grep -i "$PATTERN" || true)

	if [ ${#CONTAINERS[@]} -eq 0 ]; then
		die "No running containers found matching pattern: $PATTERN"
	fi

	if [ ${#CONTAINERS[@]} -eq 1 ]; then
		# Single match - enter directly
		CONTAINER_ID="${CONTAINERS[0]%%|*}"
		CONTAINER_NAME="${CONTAINERS[0]##*|}"
		echo "Entering container: $CONTAINER_NAME"
		if [ "$USE_SUDO" -eq 1 ]; then
			exec sudo "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
		else
			exec "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
		fi
	else
		# Multiple matches - show menu
		echo "Multiple containers found matching '$PATTERN':"
		echo ""

		for i in "${!CONTAINERS[@]}"; do
			CONTAINER_NAME="${CONTAINERS[$i]##*|}"
			CONTAINER_ID="${CONTAINERS[$i]%%|*}"
			# Get container image and status
			CONTAINER_INFO=$(run_docker ps --filter "id=$CONTAINER_ID" --format "{{.Image}} | {{.Status}}" 2>/dev/null | head -1)
			echo "  $((i + 1)). $CONTAINER_NAME ($CONTAINER_INFO)"
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
		if [ "$USE_SUDO" -eq 1 ]; then
			exec sudo "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
		else
			exec "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
		fi
	fi
	;;
*)
	echo "Error: Unknown command '$COMMAND'" >&2
	echo "Run 'mlh docker --help' for available commands." >&2
	exit 1
	;;
esac
