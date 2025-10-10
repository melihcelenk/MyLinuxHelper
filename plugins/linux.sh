#!/usr/bin/env bash
# linux.sh — Launch/Manage isolated Linux containers quickly.
#
# Usage:
#   linux [options] <name>
#   linux --help
#
# Default mode (no flag): ephemeral tmp (-t): run a container and remove on exit.
#
# Modes:
#   -t, --tmp                   Ephemeral: create/run and auto-remove on exit (default)
#   -p, --permanent             Permanent: create (if missing), start, and enter; NOT removed on exit
#   -s, --stop                  Stop the container <name>
#   -d, --delete                Stop (if running) and remove the container <name>
#
# Extra options:
#   -i, --image <image>         Base image (default: ubuntu:24.04)
#   -m, --mount <host:cont>     Bind mount (repeatable). Example: -m "$PWD:/workspace"
#       --no-mlh                Do NOT mount MyLinuxHelper repo into /opt/mlh
#       --shell <sh>            Shell to start inside (default: bash)
#   -h, --help                  Show help
#
# Notes:
# - Inside the container, if /opt/mlh/install.sh exists, it will be sourced automatically,
#   so you can immediately use: `i <package>` and other MLH helpers.
# - Requires Docker.

set -euo pipefail

# Defaults
MODE="tmp"                        # tmp | permanent | stop | delete
IMAGE="ubuntu:24.04"
MOUNTS=()
MOUNT_MLH=1
SHELL_BIN="bash"

print_help() {
  cat <<'EOF'
Usage:
  linux [options] <name>
  linux --help

Modes:
  -t, --tmp                    Ephemeral (default). Run container and auto-remove on exit.
  -p, --permanent              Permanent. Create (if missing), start, and enter. Not removed on exit.
  -s, --stop                   Stop the container <name>.
  -d, --delete                 Stop (if running) and remove the container <name>.

Extra options:
  -i, --image <image>          Base image (default: ubuntu:24.04).
  -m, --mount <host:cont>      Bind mount (repeatable). Example: -m "$PWD:/workspace"
      --no-mlh                 Do NOT mount MyLinuxHelper into /opt/mlh.
      --shell <sh>             Shell inside container (default: bash).
  -h, --help                   Show this help.

Examples:
  linux deneme1
  linux -t -i debian:12 deneme1
  linux -p -m "$PWD:/workspace" deneme1
  linux -s deneme1
  linux -d deneme1
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_docker() {
  have_cmd docker || die "Docker is required but not found in PATH."
}

# Resolve repo root to optionally mount /opt/mlh
resolve_mlh_root() {
  local source="$0"
  # In case called via symlink (e.g., ~/.local/bin/linux -> plugins/linux.sh):
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
  local plugin_dir
  plugin_dir="$(cd -P "$(dirname "$source")" && pwd)"
  # Root is one level up (repo root containing install.sh, setup.sh, plugins/)
  echo "$(dirname "$plugin_dir")"
}

# Parse arguments (support short + long + repeatable -m)
NAME=""
while (( $# )); do
  case "$1" in
    -t|--tmp) MODE="tmp"; shift ;;
    -p|--permanent) MODE="permanent"; shift ;;
    -s|--stop) MODE="stop"; shift ;;
    -d|--delete) MODE="delete"; shift ;;
    -i|--image)
      shift; [ $# -ge 1 ] || die "Missing value for --image"
      IMAGE="$1"; shift ;;
    -m|--mount)
      shift; [ $# -ge 1 ] || die "Missing value for --mount"
      MOUNTS+=("$1"); shift ;;
    --no-mlh) MOUNT_MLH=0; shift ;;
    --shell)
      shift; [ $# -ge 1 ] || die "Missing value for --shell"
      SHELL_BIN="$1"; shift ;;
    -h|--help) print_help; exit 0 ;;
    --) shift; break ;;
    -*)
      die "Unknown option: $1 (use --help)"
      ;;
    *)
      # First non-option is container name
      if [ -z "${NAME:-}" ]; then
        NAME="$1"; shift
      else
        die "Unexpected argument: $1"
      fi
      ;;
  esac
done

[ -n "${NAME:-}" ] || { print_help; exit 1; }
ensure_docker

# Build docker -v args
DOCKER_MOUNTS=()
for m in "${MOUNTS[@]}"; do
  DOCKER_MOUNTS+=("-v" "$m")
done

# Optionally mount MyLinuxHelper repo to /opt/mlh (read-only)
if [ "$MOUNT_MLH" -eq 1 ]; then
  MLH_ROOT="$(resolve_mlh_root)"
  if [ -f "$MLH_ROOT/install.sh" ]; then
    DOCKER_MOUNTS+=("-v" "$MLH_ROOT:/opt/mlh:ro")
  fi
fi

# Shell entry: add MLH plugins to PATH and make 'i' function available
ENTRY_CMD='
  if [ -d /opt/mlh ]; then
    PATH="/opt/mlh/plugins:$PATH"; export PATH;
  fi;
  if [ -f /opt/mlh/install.sh ]; then
    . /opt/mlh/install.sh;
    export -f i 2>/dev/null || true;
    export -f _install_detect_manager 2>/dev/null || true;
    export -f _install_do 2>/dev/null || true;
  fi;
  # wrapper functions (no .sh suffix)
  isjsonvalid() { bash /opt/mlh/plugins/isjsonvalid.sh "$@"; }; export -f isjsonvalid 2>/dev/null || true;
  ll() { bash /opt/mlh/plugins/ll.sh "$@"; }; export -f ll 2>/dev/null || true;
  exec '"$SHELL_BIN"' -i
'

# Helpers for state checks
container_exists() { docker inspect "$1" >/dev/null 2>&1; }
container_running() { docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -qi true; }

case "$MODE" in
  tmp)
    # Ephemeral: docker run --rm -it --name NAME ...
    exec docker run --rm -it --name "$NAME" "${DOCKER_MOUNTS[@]}" "$IMAGE" "$SHELL_BIN" -c "$ENTRY_CMD"
    ;;

  permanent)
    if ! container_exists "$NAME"; then
      # Create with interactive TTY for future attaches
      docker create -it --name "$NAME" "${DOCKER_MOUNTS[@]}" "$IMAGE" "$SHELL_BIN"
    fi
    # Start if not running
    if ! container_running "$NAME"; then
      docker start "$NAME" >/dev/null
    fi
    # Enter (exec) with MLH sourced
    exec docker exec -it "$NAME" "$SHELL_BIN" -c "$ENTRY_CMD"
    ;;

  stop)
    container_exists "$NAME" || die "Container '$NAME' does not exist."
    if container_running "$NAME"; then
      docker stop "$NAME" >/dev/null
      echo "Stopped: $NAME"
    else
      echo "Container '$NAME' is not running."
    fi
    ;;

  delete)
    # Stop if running, then remove
    if container_exists "$NAME"; then
      if container_running "$NAME"; then
        docker stop "$NAME" >/dev/null || true
      fi
      docker rm "$NAME" >/dev/null
      echo "Deleted: $NAME"
    else
      echo "Container '$NAME' does not exist."
    fi
    ;;

  *)
    die "Unknown mode: $MODE"
    ;;
esac
