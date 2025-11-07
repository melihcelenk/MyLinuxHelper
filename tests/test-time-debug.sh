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

# Test parse_relative_time function
if [ "$seconds_3m" -eq 180 ]; then
	print_test_result "parse_relative_time('3m') returns correct value" "PASS"
else
	print_test_result "parse_relative_time('3m') returns correct value" "FAIL" "Expected 180, got $seconds_3m"
fi

# Test timestamp_to_date function
test_ts=$current_ts
test_date=$(timestamp_to_date "$test_ts")
if [ -n "$test_date" ] && [[ "$test_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
	print_test_result "timestamp_to_date() produces valid date format" "PASS"
else
	print_test_result "timestamp_to_date() produces valid date format" "FAIL" "Invalid date format: $test_date"
fi

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

echo ""
echo "=== Testing with controlled timestamps ==="

# Test 3: Create test data with known timestamps and verify time filtering
test_histfile=$(mktemp)
test_current=$current_ts
test_5m_ago=$((test_current - 300))  # 5 minutes ago
test_1h_ago=$((test_current - 3600)) # 1 hour ago

cat >"$test_histfile" <<EOF
#$test_1h_ago
command from 1 hour ago
#$test_5m_ago
command from 5 minutes ago
#$test_current
recent command
EOF

# Save original HISTFILE and use test file
original_histfile="${HISTFILE:-}"
export HISTFILE="$test_histfile"

# Test that parse_history_with_timestamps can read the test file
test_output=$(parse_history_with_timestamps 2>&1)
if echo "$test_output" | grep -q "command from 1 hour ago" && \
   echo "$test_output" | grep -q "command from 5 minutes ago" && \
   echo "$test_output" | grep -q "recent command"; then
	print_test_result "parse_history_with_timestamps reads all commands" "PASS"
else
	print_test_result "parse_history_with_timestamps reads all commands" "FAIL" "Failed to parse test history file"
fi

# Test filter_by_date with 10 minute window (should get 2 commands)
filter_output=$(filter_by_date "10m" 2>&1)
# Should get at least 2 commands from our test data: 5m ago and current
# (1h ago command is outside the 10m window)
if echo "$filter_output" | grep -q "command from 5 minutes ago" && \
   echo "$filter_output" | grep -q "recent command"; then
	print_test_result "filter_by_date correctly filters by time range" "PASS"
else
	print_test_result "filter_by_date correctly filters by time range" "FAIL" "Could not find expected commands in 10m range"
fi

# Restore original HISTFILE
if [ -n "$original_histfile" ]; then
	export HISTFILE="$original_histfile"
else
	unset HISTFILE
fi
rm -f "$test_histfile"
