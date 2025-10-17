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

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
  cat <<EOF
Usage: isjsonvalid [OPTIONS] <file.json>
       isjsonvalid --help

Checks if the given file is valid JSON using 'jq'.

Options:
  -d, --detail        Show detailed validation output with colors
  -h, --help          Show this help message

Output (default mode):
  - "Yes"  if JSON is valid
  - "No"   if JSON is invalid
  - "Error: \"<file>\" not found" if file is missing

Output (detailed mode):
  - "✓ Valid JSON"    if JSON is valid (green)
  - "✗ Invalid JSON"  if JSON is invalid (red)
  - Error details and line numbers for invalid JSON

Examples:
  isjsonvalid data.json              # Quick validation (Yes/No)
  isjsonvalid -d data.json           # Detailed validation
  isjsonvalid --detail data.json     # Detailed validation
  isjsonvalid *.json                 # Validate multiple files
EOF
}

# Parse arguments
DETAIL_MODE=false
FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    -d|--detail)
      DETAIL_MODE=true
      shift
      ;;
    *)
      if [[ -z "$FILE" ]]; then
        FILE="$1"
      else
        echo "Error: unexpected argument '$1'"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Error: no file specified"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  if [[ "$DETAIL_MODE" == true ]]; then
    echo -e "${RED}Error: File '$FILE' not found.${NC}"
  else
    echo "Error: \"$FILE\" not found"
  fi
  exit 1
fi

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  i jq || { echo "Error: failed to install jq"; exit 1; }
fi

# Validate JSON
if [[ "$DETAIL_MODE" == true ]]; then
  # Detailed output
  if jq empty "$FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Valid JSON${NC}"
    exit 0
  else
    echo -e "${RED}✗ Invalid JSON${NC}"
    echo -e "${YELLOW}Details:${NC}"
    jq empty "$FILE" 2>&1
    exit 1
  fi
else
  # Simple Yes/No output
  if jq empty "$FILE" >/dev/null 2>&1; then
    echo "Yes"
  else
    echo "No"
  fi
fi
