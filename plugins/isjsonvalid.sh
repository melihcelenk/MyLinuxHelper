#!/bin/bash
# isjsonvalid.sh — Validate JSON file integrity using jq. Prints Yes / No / Error.

# Resolve own real path (follows symlinks) to find repo root
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  TARGET="$(readlink "$SOURCE")"
  if [[ $TARGET == /* ]]; then
    SOURCE="$TARGET"
  else
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$DIR/$TARGET"
  fi
done
PLUGIN_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ROOT_DIR="$(dirname "$PLUGIN_DIR")"

# Load installer function i (for ensuring jq)
# shellcheck source=/dev/null
. "$ROOT_DIR/install.sh"

show_help() {
  cat <<EOF
Usage: isjsonvalid <file.json>
       isjsonvalid --help

Checks if the given file is valid JSON using 'jq'.
Output:
  - "Yes"  if JSON is valid
  - "No"   if JSON is invalid
  - "Error: \"<file>\" not found" if file is missing
EOF
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_help
  exit 0
fi

if [ -z "$1" ]; then
  echo "Error: no file specified"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "Error: \"$1\" not found"
  exit 1
fi

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  i jq || { echo "Error: failed to install jq"; exit 1; }
fi

# Validate JSON
if jq empty "$1" >/dev/null 2>&1; then
  echo "Yes"
else
  echo "No"
fi
