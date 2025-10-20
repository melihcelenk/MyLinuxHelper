#!/usr/bin/env bash
# test-time-debug.sh - Debug time filtering issues

set +e

# Get ROOT_DIR if not set
if [ -z "${ROOT_DIR:-}" ]; then
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	ROOT_DIR="$(dirname "$SCRIPT_DIR")"
fi

HISTORY_SCRIPT="$ROOT_DIR/plugins/mlh-history.sh"
TEMP_SCRIPT=$(mktemp)
sed -e '/^main "\$@"$/d' -e '/^set -euo pipefail$/d' "$HISTORY_SCRIPT" >"$TEMP_SCRIPT"
# shellcheck source=/dev/null
source "$TEMP_SCRIPT"
rm -f "$TEMP_SCRIPT"

echo "=== Time Debug Information ==="
echo ""

# Get current system time
current_ts=$(date +%s)
echo "Current timestamp: $current_ts"
echo "Current time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get last history entry
histfile="${HISTFILE:-$HOME/.bash_history}"
if [ -f "$histfile" ]; then
	echo "History file: $histfile"
	echo "Last 10 lines of history file:"
	tail -10 "$histfile"
	echo ""

	# Parse last timestamp
	last_ts=""
	while IFS= read -r line; do
		if [[ "$line" =~ ^#([0-9]+)$ ]]; then
			last_ts="${BASH_REMATCH[1]}"
		fi
	done <"$histfile"

	if [ -n "$last_ts" ]; then
		echo "Last history timestamp: $last_ts"
		echo "Last history time: $(timestamp_to_date "$last_ts")"

		diff_seconds=$((current_ts - last_ts))
		diff_minutes=$((diff_seconds / 60))
		diff_hours=$((diff_seconds / 3600))

		echo ""
		echo "Time difference:"
		echo "  Seconds: $diff_seconds"
		echo "  Minutes: $diff_minutes"
		echo "  Hours: $diff_hours"
		echo ""

		if [ "$diff_seconds" -lt 180 ]; then
			echo "✓ Last command was within 3 minutes"
		else
			echo "⚠ Last command was MORE than 3 minutes ago"
		fi
	else
		echo "⚠ No timestamps found in history"
	fi
else
	echo "⚠ History file not found"
fi

echo ""
echo "=== Testing parse_history_with_timestamps ==="
temp_file=$(mktemp)
parse_history_with_timestamps >"$temp_file" 2>&1
echo "Last 5 parsed entries:"
tail -5 "$temp_file"
rm -f "$temp_file"

echo ""
echo "=== Testing relative time for 3m ==="
seconds_3m=$(parse_relative_time "3m")
echo "3m = $seconds_3m seconds (expected: 180)"

end_ts=$current_ts
start_ts=$((end_ts - seconds_3m))
echo "Start timestamp: $start_ts ($(timestamp_to_date "$start_ts"))"
echo "End timestamp: $end_ts ($(timestamp_to_date "$end_ts"))"

if [ -n "$last_ts" ]; then
	echo ""
	if [ "$last_ts" -ge "$start_ts" ] && [ "$last_ts" -le "$end_ts" ]; then
		echo "✓ Last history entry ($last_ts) IS within range [$start_ts - $end_ts]"
	else
		echo "✗ Last history entry ($last_ts) is NOT within range [$start_ts - $end_ts]"
		echo "  last_ts >= start_ts: $last_ts >= $start_ts = $([ "$last_ts" -ge "$start_ts" ] && echo "true" || echo "false")"
		echo "  last_ts <= end_ts: $last_ts <= $end_ts = $([ "$last_ts" -le "$end_ts" ] && echo "true" || echo "false")"
	fi
fi
