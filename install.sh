#!/usr/bin/env bash
# install.sh — Universal, safe installer. Provides CLI and function "i".

_install_detect_manager() {
  command -v apt >/dev/null 2>&1 && { echo "apt"; return; }
  command -v apt-get >/dev/null 2>&1 && { echo "apt-get"; return; }
  command -v dnf >/dev/null 2>&1 && { echo "dnf"; return; }
  command -v yum >/dev/null 2>&1 && { echo "yum"; return; }
  command -v zypper >/dev/null 2>&1 && { echo "zypper"; return; }
  command -v pacman >/dev/null 2>&1 && { echo "pacman"; return; }
  command -v apk >/dev/null 2>&1 && { echo "apk"; return; }
  echo ""
}

# run installer with/without sudo depending on $USE_SUDO (0/1)
_install_do() {
  local manager="$1"; shift
  local use_sudo="${USE_SUDO:-1}"
  local pkg rc

  # optionally cache sudo (only if needed)
  if [ "$use_sudo" -eq 1 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
      echo "Error: sudo not found and current user is not root."
      return 1
    fi
    if ! sudo -v 2>/dev/null; then
      echo "Requesting sudo permission..."
      sudo -v || { echo "Error: sudo authentication failed."; return 1; }
    fi
  fi

  echo "Using package manager: $manager"

  for pkg in "$@"; do
    echo "Installing: $pkg ..."
    rc=0
    case "$manager" in
      apt)
        [ "$use_sudo" -eq 1 ] && sudo apt update -y && sudo apt install -y "$pkg" || { apt update -y && apt install -y "$pkg"; }
        rc=$?
        ;;
      apt-get)
        [ "$use_sudo" -eq 1 ] && sudo apt-get update -y && sudo apt-get install -y "$pkg" || { apt-get update -y && apt-get install -y "$pkg"; }
        rc=$?
        ;;
      dnf)
        [ "$use_sudo" -eq 1 ] && sudo dnf install -y "$pkg" || dnf install -y "$pkg"
        rc=$?
        ;;
      yum)
        [ "$use_sudo" -eq 1 ] && sudo yum install -y "$pkg" || yum install -y "$pkg"
        rc=$?
        ;;
      zypper)
        [ "$use_sudo" -eq 1 ] && sudo zypper install -y "$pkg" || zypper install -y "$pkg"
        rc=$?
        ;;
      pacman)
        [ "$use_sudo" -eq 1 ] && sudo pacman -Sy --noconfirm "$pkg" || pacman -Sy --noconfirm "$pkg"
        rc=$?
        ;;
      apk)
        [ "$use_sudo" -eq 1 ] && sudo apk add "$pkg" || apk add "$pkg"
        rc=$?
        ;;
    esac
    if [ $rc -ne 0 ]; then
      echo "Error: installer returned non-zero exit code for '$pkg'."
      return 1
    fi

    # verify via package DB
    case "$manager" in
      apt|apt-get) dpkg -s "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by dpkg."; return 1; } ;;
      dnf|yum|zypper) rpm -q "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by rpm."; return 1; } ;;
      pacman) pacman -Qi "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by pacman."; return 1; } ;;
      apk) apk info -e "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by apk."; return 1; } ;;
    esac

    echo "✅ '$pkg' installed (verified)."
  done
}

i() {
  # help first
  if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat <<'EOF'
Usage: i <package> [<package> ...]

Smart package installer - automatically detects your package manager.

Supported package managers:
  apt, apt-get, dnf, yum, zypper, pacman, apk

Examples:
  i nginx                     # Install nginx
  i git curl wget             # Install multiple packages
EOF
    return 0
  fi

  local manager; manager="$(_install_detect_manager)"
  [ -z "$manager" ] && { echo "Error: no supported package manager found."; return 1; }

  # decide sudo usage: if root, no sudo; else use sudo if available
  if [ "$(id -u)" -eq 0 ]; then
    USE_SUDO=0 _install_do "$manager" "$@"
  else
    USE_SUDO=1 _install_do "$manager" "$@"
  fi
}

# CLI mode when executed directly (symlink ~/.local/bin/i -> install.sh)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [ "$#" -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat <<'EOF'
Usage: i <package> [<package> ...]

Smart package installer - automatically detects your package manager.

Supported package managers:
  apt, apt-get, dnf, yum, zypper, pacman, apk

Examples:
  i nginx                     # Install nginx
  i git curl wget             # Install multiple packages
EOF
    exit 0
  fi
  i "$@"
fi
