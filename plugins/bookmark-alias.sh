#!/usr/bin/env bash
# bookmark-alias.sh - Simple proxy script that delegates to mlh-bookmark.sh
#
# This script is created by setup.sh with the user's chosen alias name.
# It simply forwards all arguments to the actual bookmark implementation.

set -euo pipefail

# Resolve the script location (handle symlinks)
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
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# Delegate to mlh-bookmark.sh
exec "$SCRIPT_DIR/mlh-bookmark.sh" "$@"
