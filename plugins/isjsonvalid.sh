#!/bin/bash
# isjsonvalid.sh — Validate JSON file integrity using jq.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$PLUGIN_DIR")"

# Load 'i' function
# shellcheck source=/dev/null
. "$ROOT_DIR/install.sh"

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
  i jq
fi

# Argument presence check
if [ -z "$1" ]; then
  echo "Error: no file specified"
  exit 1
fi

# File existence check
if [ ! -f "$1" ]; then
  echo "Error: \"$1\" not found"
  exit 1
fi

# Validate JSON
if jq empty "$1" >/dev/null 2>&1; then
  echo "Yes"
else
  echo "No"
fi
