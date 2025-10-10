#!/bin/bash
# install.sh — Universal package installer.
# - When *sourced*, defines function: i
# - When *executed as a program*, behaves like CLI: i <pkg> [<pkg>...]

_install_detect_manager() {
  if command -v apt >/dev/null 2>&1; then echo "apt"; return; fi
  if command -v apt-get >/dev/null 2>&1; then echo "apt-get"; return; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
  if command -v yum >/dev/null 2>&1; then echo "yum"; return; fi
  if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
  if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
  if command -v apk >/dev/null 2>&1; then echo "apk"; return; fi
  echo ""
}

_install_do() {
  local manager="$1"; shift
  local pkg rc

  # Sudo once (interactive if needed)
  if ! sudo -v 2>/dev/null; then
    echo "Requesting sudo permission..."
    sudo -v || { echo "Error: sudo authentication failed."; return 1; }
  fi

  echo "Using package manager: $manager"
  for pkg in "$@"; do
    echo "Installing: $pkg ..."
    rc=0
    case "$manager" in
      apt)     sudo apt update -y && sudo apt install -y "$pkg"; rc=$? ;;
      apt-get) sudo apt-get update -y && sudo apt-get install -y "$pkg"; rc=$? ;;
      dnf)     sudo dnf install -y "$pkg"; rc=$? ;;
      yum)     sudo yum install -y "$pkg"; rc=$? ;;
      zypper)  sudo zypper install -y "$pkg"; rc=$? ;;
      pacman)  sudo pacman -Sy --noconfirm "$pkg"; rc=$? ;;
      apk)     sudo apk add "$pkg"; rc=$? ;;
    esac
    if [ $rc -ne 0 ]; then
      echo "Error: installer returned non-zero exit code for '$pkg'."
      return 1
    fi

    # Verify by package DB
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
  if [ $# -lt 1 ]; then
    echo "Usage: i <package> [<package> ...]"
    echo "Installs packages using the detected package manager (apt, dnf, yum, zypper, pacman, apk)."
    return 1
  fi
  local manager; manager="$(_install_detect_manager)"
  [ -z "$manager" ] && { echo "Error: no supported package manager found."; return 1; }
  _install_do "$manager" "$@"
}

# --- CLI mode: if executed directly (not sourced), act like a program named "i"
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ $# -lt 1 ]; then
    echo "Usage: i <package> [<package> ...]"
    echo "Installs packages using: apt | apt-get | dnf | yum | zypper | pacman | apk"
    exit 0
  fi
  i "$@"
fi
