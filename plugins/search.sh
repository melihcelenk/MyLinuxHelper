#!/usr/bin/env bash
# search.sh — Fast file search in current directory and subdirectories
#
# Usage:
#   search <pattern> [path]
#   search --help
#
# Examples:
#   search myfile              # Search for 'myfile' in current directory
#   search "*.json"            # Search for all JSON files
#   search config /etc         # Search for 'config' in /etc

set -euo pipefail

show_help() {
	cat <<'EOF'
Usage: search <pattern> [path]
       search --help

Fast file search using find command.
Searches in current directory by default, or in specified path.

Arguments:
  pattern    File name pattern to search for (supports wildcards)
  path       Optional: directory to search in (default: current directory)

Examples:
  search myfile              # Search for 'myfile' in current directory
  search "*.json"            # Search for all JSON files
  search config.js           # Search for config.js
  search "test*" ./src       # Search for files starting with 'test' in src/
  search "*.conf" /etc       # Search for .conf files in /etc

Notes:
  - Search is case-sensitive by default
  - Use quotes for patterns with wildcards (*, ?, etc.)
  - Shows relative paths from search directory
EOF
}

if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	show_help
	exit 0
fi

PATTERN="$1"
SEARCH_PATH="${2:-.}"

# Check if search path exists
if [ ! -d "$SEARCH_PATH" ]; then
	echo "Error: Directory '$SEARCH_PATH' does not exist" >&2
	exit 1
fi

# Perform search
echo "Searching for '$PATTERN' in $SEARCH_PATH..."
echo ""

# Use find with -iname for case-insensitive search
# If pattern contains wildcards, use -name, otherwise use -iname
if [[ "$PATTERN" == *"*"* ]] || [[ "$PATTERN" == *"?"* ]]; then
	# Pattern has wildcards, use -name (case-sensitive)
	RESULTS=$(find "$SEARCH_PATH" -type f -name "$PATTERN" 2>/dev/null || true)
else
	# No wildcards, use -iname (case-insensitive) for better UX
	RESULTS=$(find "$SEARCH_PATH" -type f -iname "*${PATTERN}*" 2>/dev/null || true)
fi

if [ -z "$RESULTS" ]; then
	echo "No files found matching '$PATTERN'"
	exit 1
fi

# Count results
COUNT=$(echo "$RESULTS" | wc -l)

# Display results
echo "$RESULTS"
echo ""
echo "Found $COUNT file(s)"
