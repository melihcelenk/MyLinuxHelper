#!/bin/bash
# install.sh — Universal, safe installer function named "i".
# Verifies installation via the system's package database (dpkg/rpm/pacman/apk).

i() {
  if [ $# -lt 1 ]; then
    echo "Error: no package specified for i()"
    return 1
  fi

  # Detect package manager once
  local manager=""
  if command -v apt >/dev/null 2>&1; then
    manager="apt"
  elif command -v apt-get >/dev/null 2>&1; then
    manager="apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    manager="dnf"
  elif command -v yum >/dev/null 2>&1; then
    manager="yum"
  elif command -v zypper >/dev/null 2>&1; then
    manager="zypper"
  elif command -v pacman >/dev/null 2>&1; then
    manager="pacman"
  elif command -v apk >/dev/null 2>&1; then
    manager="apk"
  else
    echo "Error: no supported package manager found."
    return 1
  fi

  # Sudo cache (interactive prompt if needed)
  if ! sudo -v 2>/dev/null; then
    echo "Requesting sudo permission..."
    sudo -v || { echo "Error: sudo authentication failed."; return 1; }
  fi

  echo "Using package manager: $manager"

  local pkg
  for pkg in "$@"; do
    echo "Installing: $pkg ..."
    local rc=0

    case "$manager" in
      apt)
        sudo apt update -y && sudo apt install -y "$pkg"; rc=$?
        ;;
      apt-get)
        sudo apt-get update -y && sudo apt-get install -y "$pkg"; rc=$?
        ;;
      dnf)
        sudo dnf install -y "$pkg"; rc=$?
        ;;
      yum)
        sudo yum install -y "$pkg"; rc=$?
        ;;
      zypper)
        sudo zypper install -y "$pkg"; rc=$?
        ;;
      pacman)
        sudo pacman -Sy --noconfirm "$pkg"; rc=$?
        ;;
      apk)
        sudo apk add "$pkg"; rc=$?
        ;;
    esac

    if [ $rc -ne 0 ]; then
      echo "Error: installer returned non-zero exit code for '$pkg'."
      return 1
    fi

    # Verify via package database (not by command name)
    case "$manager" in
      apt|apt-get)
        dpkg -s "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by dpkg."; return 1; }
        ;;
      dnf|yum|zypper)
        rpm -q "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by rpm."; return 1; }
        ;;
      pacman)
        pacman -Qi "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by pacman."; return 1; }
        ;;
      apk)
        apk info -e "$pkg" >/dev/null 2>&1 || { echo "Error: '$pkg' not marked installed by apk."; return 1; }
        ;;
    esac

    echo "✅ '$pkg' installed (verified)."
  done
}
