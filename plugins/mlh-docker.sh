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

set -uo pipefail
# Note: We don't use 'set -e' because we need to handle errors manually
# for proper sudo detection and error messages

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

	# Force use of system Docker daemon at /var/run/docker.sock
	# Docker Desktop socket may be configured but not running
	# Check if system Docker socket exists, if so use it
	if [ -S "/var/run/docker.sock" ]; then
		# Use system Docker daemon explicitly
		export DOCKER_HOST="unix:///var/run/docker.sock"
	elif [ -n "${DOCKER_HOST:-}" ] && echo "$DOCKER_HOST" | grep -q "docker-desktop\|\.docker/desktop"; then
		# Docker Desktop socket configured but may not be running
		# Unset it to let Docker client use default
		unset DOCKER_HOST
	fi

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
	# Use sudo -E to preserve environment variables (especially PATH)
	run_docker() {
		if [ "$USE_SUDO" -eq 1 ]; then
			sudo -E "$DOCKER_BIN" "$@"
		else
			"$DOCKER_BIN" "$@"
		fi
	}

	# Test Docker access and determine if sudo is needed
	# Strategy: Always try without sudo first, if it fails with permission error, use sudo
	# Use array to avoid ShellCheck warning about command substitution in string
	DOCKER_TEST_OUTPUT=$("$DOCKER_BIN" ps --format "{{.ID}}" 2>&1)
	DOCKER_TEST_EXIT=$?

	# Check if we need sudo
	if [ $DOCKER_TEST_EXIT -ne 0 ]; then
		# Check if it's a permission error
		if echo "$DOCKER_TEST_OUTPUT" | grep -qiE "permission denied|cannot connect to the docker daemon|Got permission denied|permission denied while trying to connect|dial unix.*permission denied"; then
			# Try with sudo (but handle password prompts gracefully)
			if command -v sudo >/dev/null 2>&1; then
				# Check if we're in an interactive terminal (TTY)
				if [ -t 0 ] && [ -t 1 ]; then
					# Interactive mode: Try sudo (may prompt for password)
					SUDO_TEST_OUTPUT=$(sudo "$DOCKER_BIN" ps --format "{{.ID}}" 2>&1)
					SUDO_TEST_EXIT=$?
					if [ $SUDO_TEST_EXIT -eq 0 ]; then
						USE_SUDO=1
					else
						# Check if it's a password prompt error
						if echo "$SUDO_TEST_OUTPUT" | grep -qiE "password is required|a terminal is required"; then
							die "Docker requires sudo permissions, but password authentication failed. Please run: sudo mlh docker in $PATTERN"
						else
							die "Cannot access Docker daemon even with sudo. Error: $SUDO_TEST_OUTPUT"
						fi
					fi
				else
					# Non-interactive mode: Cannot prompt for password
					# Check if sudo can work without password (NOPASSWD)
					SUDO_TEST_OUTPUT=$(sudo -n "$DOCKER_BIN" ps --format "{{.ID}}" 2>&1)
					SUDO_TEST_EXIT=$?
					if [ $SUDO_TEST_EXIT -eq 0 ]; then
						USE_SUDO=1
					else
						# Sudo requires password but we're non-interactive
						die "Docker requires sudo permissions, but we're in a non-interactive session. Please either:
  1. Run this command in an interactive terminal: mlh docker in $PATTERN
  2. Or run with sudo directly: sudo mlh docker in $PATTERN
  3. Or add your user to the docker group: sudo usermod -aG docker \$USER (then logout/login)
Original error: $DOCKER_TEST_OUTPUT"
					fi
				fi
			else
				die "Docker requires sudo permissions, but sudo is not available. Error: $DOCKER_TEST_OUTPUT"
			fi
		else
			# Other error
			die "Docker command failed: $DOCKER_TEST_OUTPUT"
		fi
	fi

	# Find matching containers (running only)
	# Use run_docker function which handles sudo automatically
	# Important: Use run_docker here, not direct docker command
	CONTAINERS_OUTPUT=$(run_docker ps --format "{{.ID}}|{{.Names}}" 2>&1)
	CONTAINERS_EXIT=$?

	if [ $CONTAINERS_EXIT -ne 0 ]; then
		die "Failed to list Docker containers. Exit code: $CONTAINERS_EXIT. Error: $CONTAINERS_OUTPUT"
	fi

	# Check if we got any output at all (even empty line means no containers)
	if [ -z "$CONTAINERS_OUTPUT" ] || [ "$(echo "$CONTAINERS_OUTPUT" | tr -d '\n' | tr -d ' ')" = "" ]; then
		die "No containers are currently running. Start a container first."
	fi

	# Filter containers by pattern (case-insensitive)
	mapfile -t CONTAINERS < <(echo "$CONTAINERS_OUTPUT" | grep -i "$PATTERN" || true)

	if [ ${#CONTAINERS[@]} -eq 0 ]; then
		# Show available containers to help user
		AVAILABLE=$(echo "$CONTAINERS_OUTPUT" | cut -d'|' -f2 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
		die "No running containers found matching pattern: $PATTERN. Available containers: $AVAILABLE"
	fi

	if [ ${#CONTAINERS[@]} -eq 1 ]; then
		# Single match - enter directly
		CONTAINER_ID="${CONTAINERS[0]%%|*}"
		CONTAINER_NAME="${CONTAINERS[0]##*|}"
		echo "Entering container: $CONTAINER_NAME"
		# Try bash first, then sh if bash is not available
		if [ "$USE_SUDO" -eq 1 ]; then
			# Check if bash is available in container
			if sudo "$DOCKER_BIN" exec "$CONTAINER_ID" which bash >/dev/null 2>&1; then
				exec sudo "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
			elif sudo "$DOCKER_BIN" exec "$CONTAINER_ID" which sh >/dev/null 2>&1; then
				exec sudo "$DOCKER_BIN" exec -it "$CONTAINER_ID" sh
			else
				die "Neither bash nor sh found in container $CONTAINER_NAME"
			fi
		else
			# Check if bash is available in container
			if "$DOCKER_BIN" exec "$CONTAINER_ID" which bash >/dev/null 2>&1; then
				exec "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
			elif "$DOCKER_BIN" exec "$CONTAINER_ID" which sh >/dev/null 2>&1; then
				exec "$DOCKER_BIN" exec -it "$CONTAINER_ID" sh
			else
				die "Neither bash nor sh found in container $CONTAINER_NAME"
			fi
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
		# Try bash first, then sh if bash is not available
		if [ "$USE_SUDO" -eq 1 ]; then
			# Check if bash is available in container
			if sudo "$DOCKER_BIN" exec "$CONTAINER_ID" which bash >/dev/null 2>&1; then
				exec sudo "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
			elif sudo "$DOCKER_BIN" exec "$CONTAINER_ID" which sh >/dev/null 2>&1; then
				exec sudo "$DOCKER_BIN" exec -it "$CONTAINER_ID" sh
			else
				die "Neither bash nor sh found in container $CONTAINER_NAME"
			fi
		else
			# Check if bash is available in container
			if "$DOCKER_BIN" exec "$CONTAINER_ID" which bash >/dev/null 2>&1; then
				exec "$DOCKER_BIN" exec -it "$CONTAINER_ID" bash
			elif "$DOCKER_BIN" exec "$CONTAINER_ID" which sh >/dev/null 2>&1; then
				exec "$DOCKER_BIN" exec -it "$CONTAINER_ID" sh
			else
				die "Neither bash nor sh found in container $CONTAINER_NAME"
			fi
		fi
	fi
	;;
*)
	echo "Error: Unknown command '$COMMAND'" >&2
	echo "Run 'mlh docker --help' for available commands." >&2
	exit 1
	;;
esac
