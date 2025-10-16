#!/usr/bin/env bash
# mlh-about.sh — About page for MyLinuxHelper
#
# Usage:
#   mlh-about.sh
#   mlh about

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

# Source version information from mlh-version.sh
get_version_info() {
  local version_script="${SCRIPT_DIR}/mlh-version.sh"

  if [ -f "$version_script" ]; then
    # Extract version constants from mlh-version.sh
    local version
    local version_date
    local first_release_date

    version=$(grep '^readonly VERSION=' "$version_script" | cut -d'"' -f2)
    version_date=$(grep '^readonly VERSION_DATE=' "$version_script" | cut -d'"' -f2)
    first_release_date=$(grep '^readonly FIRST_RELEASE_DATE=' "$version_script" | cut -d'"' -f2)

    echo "${version}|${version_date}|${first_release_date}"
  else
    echo "1.3.0|17.10.2025|11.10.2025"
  fi
}

# Get latest release from GitHub
get_latest_release() {
  local api_url="https://api.github.com/repos/melihcelenk/MyLinuxHelper/releases/latest"
  local api_response=""
  local latest_version=""
  local release_date=""

  # Try curl first, then wget
  if command -v curl &> /dev/null; then
    api_response=$(curl -s -f "$api_url" 2>/dev/null)
  elif command -v wget &> /dev/null; then
    api_response=$(wget -qO- "$api_url" 2>/dev/null)
  fi

  if [ -n "$api_response" ]; then
    # Extract tag_name
    latest_version=$(echo "$api_response" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
    # Remove 'v' prefix if exists
    latest_version="${latest_version#v}"

    # Extract published_at date and format it
    local published_at
    published_at=$(echo "$api_response" | grep -o '"published_at": *"[^"]*"' | cut -d'"' -f4)

    if [ -n "$published_at" ]; then
      # Convert ISO date to DD.MM.YYYY format
      # Input: 2025-10-13T21:33:15Z
      # Output: 13.10.2025
      release_date=$(date -d "$published_at" '+%d.%m.%Y' 2>/dev/null || date -j -f '%Y-%m-%dT%H:%M:%SZ' "$published_at" '+%d.%m.%Y' 2>/dev/null)
    fi
  fi

  echo "${latest_version}|${release_date}"
}

show_about() {
  local version_info
  version_info=$(get_version_info)

  local current_version
  local version_date
  local first_release_date

  current_version=$(echo "$version_info" | cut -d'|' -f1)
  version_date=$(echo "$version_info" | cut -d'|' -f2)
  first_release_date=$(echo "$version_info" | cut -d'|' -f3)

  # Get latest release from GitHub (non-blocking)
  local latest_release_info
  latest_release_info=$(get_latest_release)

  local latest_version
  local latest_date

  latest_version=$(echo "$latest_release_info" | cut -d'|' -f1)
  latest_date=$(echo "$latest_release_info" | cut -d'|' -f2)

  cat <<EOF
╔══════════════════════════════════════════════════════════╗
║          About MyLinuxHelper                             ║
╚══════════════════════════════════════════════════════════╝

A lightweight and modular collection of utility tools to
simplify your Linux experience.

Author:          Melih Çelenk
GitHub:          https://github.com/melihcelenk/MyLinuxHelper
License:         MIT License

Version Info:
  First Release: v1.0 (${first_release_date})
  Current:       v${current_version} (${version_date})
EOF

  # Show latest version if available
  if [ -n "$latest_version" ]; then
    if [ -n "$latest_date" ]; then
      echo "  Latest:        v${latest_version} (${latest_date})"
    else
      echo "  Latest:        v${latest_version} (GitHub)"
    fi
  fi

  cat <<EOF

Features:
  • Interactive command menu
  • Docker container management
  • Smart package installer
  • JSON validation
  • Fast file search
  • Automatic updates

EOF

  if [ "${1:-}" != "--no-prompt" ]; then
    read -rp "Press Enter to return to main menu..."
  fi
}

main() {
  show_about "$@"
}

main "$@"
