#!/usr/bin/env bash
# test-mlh-history.sh - Test suite for mlh-history.sh

# This file is sourced by the main test runner
# It has access to: print_test_result, ROOT_DIR, SCRIPT_DIR

# Disable strict mode for tests - we want to continue on errors
set +euo pipefail 2>/dev/null || true
set +e

HISTORY_SCRIPT="$ROOT_DIR/plugins/mlh-history.sh"

# We need to extract functions from the script without running main()
# Create a temporary version without the main call and without set -euo pipefail
TEMP_SCRIPT=$(mktemp)
sed -e '/^main "\$@"$/d' -e '/^set -euo pipefail$/d' "$HISTORY_SCRIPT" >"$TEMP_SCRIPT"

# Source the modified script to access its functions
# shellcheck source=/dev/null
source "$TEMP_SCRIPT"
rm -f "$TEMP_SCRIPT"

# Test 1: Check if script exists
if [ -f "$HISTORY_SCRIPT" ]; then
	print_test_result "mlh-history.sh exists" "PASS"
else
	print_test_result "mlh-history.sh exists" "FAIL" "File not found at: $HISTORY_SCRIPT"
fi

# Test 2: Script is executable or can be run with bash
if [ -x "$HISTORY_SCRIPT" ] || bash -n "$HISTORY_SCRIPT" 2>/dev/null; then
	print_test_result "mlh-history.sh is valid bash script" "PASS"
else
	print_test_result "mlh-history.sh is valid bash script" "FAIL" "Syntax errors found"
fi

# Test 3: parse_relative_time function - 3 days
result=$(parse_relative_time "3d")
expected=259200
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('3d') = 259200 seconds" "PASS"
else
	print_test_result "parse_relative_time('3d') = 259200 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 4: parse_relative_time function - 2 hours
result=$(parse_relative_time "2h")
expected=7200
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('2h') = 7200 seconds" "PASS"
else
	print_test_result "parse_relative_time('2h') = 7200 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 5: parse_relative_time function - 20 minutes
result=$(parse_relative_time "20m")
expected=1200
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('20m') = 1200 seconds" "PASS"
else
	print_test_result "parse_relative_time('20m') = 1200 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 6: parse_relative_time function - 1 hour
result=$(parse_relative_time "1h")
expected=3600
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('1h') = 3600 seconds" "PASS"
else
	print_test_result "parse_relative_time('1h') = 3600 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 7: parse_relative_time function - 1 day
result=$(parse_relative_time "1d")
expected=86400
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('1d') = 86400 seconds" "PASS"
else
	print_test_result "parse_relative_time('1d') = 86400 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 8: parse_relative_time function - 30 minutes
result=$(parse_relative_time "30m")
expected=1800
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('30m') = 1800 seconds" "PASS"
else
	print_test_result "parse_relative_time('30m') = 1800 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 9: parse_relative_time function - invalid format
result=$(parse_relative_time "invalid")
if [ -z "$result" ]; then
	print_test_result "parse_relative_time('invalid') returns empty" "PASS"
else
	print_test_result "parse_relative_time('invalid') returns empty" "FAIL" "Got: $result, Expected: empty"
fi

# Test 10: parse_relative_time function - invalid unit
result=$(parse_relative_time "5x")
if [ -z "$result" ]; then
	print_test_result "parse_relative_time('5x') returns empty" "PASS"
else
	print_test_result "parse_relative_time('5x') returns empty" "FAIL" "Got: $result, Expected: empty"
fi

# Test 11: timestamp_to_date function exists and works
result=$(timestamp_to_date "1729425600" 2>/dev/null)
if [ -n "$result" ]; then
	print_test_result "timestamp_to_date converts timestamp to date" "PASS"
else
	print_test_result "timestamp_to_date converts timestamp to date" "FAIL" "Function returned empty"
fi

# Test 12: Help option works
if bash "$HISTORY_SCRIPT" --help >/dev/null 2>&1; then
	print_test_result "mlh history --help works" "PASS"
else
	print_test_result "mlh history --help works" "FAIL" "Help command failed"
fi

# Test 13: Help contains relative time examples
help_output=$(bash "$HISTORY_SCRIPT" --help 2>/dev/null)
if echo "$help_output" | grep -q "mlh history -t 3d"; then
	print_test_result "Help contains relative time examples" "PASS"
else
	print_test_result "Help contains relative time examples" "FAIL" "Missing '3d' example in help"
fi

# Test 14: Help contains before offset examples
if echo "$help_output" | grep -q "\-b 1h"; then
	print_test_result "Help contains before offset examples" "PASS"
else
	print_test_result "Help contains before offset examples" "FAIL" "Missing '-b 1h' example in help"
fi

# Test 15: Help contains absolute date examples
if echo "$help_output" | grep -q "2025-10-20"; then
	print_test_result "Help contains absolute date examples" "PASS"
else
	print_test_result "Help contains absolute date examples" "FAIL" "Missing date example in help"
fi

# Test 16: Config directory variable is set
if [ -n "${CONFIG_DIR:-}" ]; then
	print_test_result "CONFIG_DIR variable is defined" "PASS"
else
	print_test_result "CONFIG_DIR variable is defined" "FAIL" "CONFIG_DIR is not set"
fi

# Test 17: get_config_value function exists
if declare -f get_config_value >/dev/null; then
	print_test_result "get_config_value function exists" "PASS"
else
	print_test_result "get_config_value function exists" "FAIL" "Function not found"
fi

# Test 18: set_config_value function exists
if declare -f set_config_value >/dev/null; then
	print_test_result "set_config_value function exists" "PASS"
else
	print_test_result "set_config_value function exists" "FAIL" "Function not found"
fi

# Test 19: check_histtimeformat function exists
if declare -f check_histtimeformat >/dev/null; then
	print_test_result "check_histtimeformat function exists" "PASS"
else
	print_test_result "check_histtimeformat function exists" "FAIL" "Function not found"
fi

# Test 20: parse_history_with_timestamps function exists
if declare -f parse_history_with_timestamps >/dev/null; then
	print_test_result "parse_history_with_timestamps function exists" "PASS"
else
	print_test_result "parse_history_with_timestamps function exists" "FAIL" "Function not found"
fi

# Test 21: filter_by_date function exists
if declare -f filter_by_date >/dev/null; then
	print_test_result "filter_by_date function exists" "PASS"
else
	print_test_result "filter_by_date function exists" "FAIL" "Function not found"
fi

# Test 22: filter_by_date accepts two parameters (date and before_offset)
# Check if function definition includes before_offset parameter
if grep -q 'local before_offset=' "$HISTORY_SCRIPT"; then
	print_test_result "filter_by_date accepts before_offset parameter" "PASS"
else
	print_test_result "filter_by_date accepts before_offset parameter" "FAIL" "before_offset parameter not found"
fi

# Test 23: Main function handles -b flag
if grep -q '\-b.*--before)' "$HISTORY_SCRIPT"; then
	print_test_result "Main function handles -b/--before flag" "PASS"
else
	print_test_result "Main function handles -b/--before flag" "FAIL" "Flag handler not found"
fi

# Test 24: Error handling for -b without -t
error_output=$(bash "$HISTORY_SCRIPT" -b 1h 2>&1 || true)
if echo "$error_output" | grep -q "requires.*time"; then
	print_test_result "Error shown when -b used without -t" "PASS"
else
	print_test_result "Error shown when -b used without -t" "FAIL" "Expected error message not found"
fi

# Test 25: Large time values - 365 days
result=$(parse_relative_time "365d")
expected=31536000
if [ "$result" = "$expected" ]; then
	print_test_result "parse_relative_time('365d') = 31536000 seconds" "PASS"
else
	print_test_result "parse_relative_time('365d') = 31536000 seconds" "FAIL" "Got: $result, Expected: $expected"
fi

# Test 26: Time filtering with recent commands (simulate)
current_ts=$(date +%s)
test_history=$(mktemp)
cat >"$test_history" <<EOF
#$((current_ts - 300))
command 5 minutes ago
#$((current_ts - 120))
command 2 minutes ago
#$((current_ts - 30))
command 30 seconds ago
EOF

# Test with 3m filter - should find 2 commands
result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" -t 3m 2>&1 | grep -c "Found.*command")
rm -f "$test_history"
if [ "$result" -eq 1 ]; then
	print_test_result "Time filter with recent commands (3m)" "PASS"
else
	print_test_result "Time filter with recent commands (3m)" "FAIL" "Expected to find commands"
fi

# Test 27: Time filtering shows helpful message when no results
test_history=$(mktemp)
old_ts=$((current_ts - 86400)) # 1 day ago
cat >"$test_history" <<EOF
#$old_ts
old command
EOF

result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" -t 3m 2>&1 | grep -c "Latest command in history")
rm -f "$test_history"
if [ "$result" -eq 1 ]; then
	print_test_result "Helpful message shown when no recent commands found" "PASS"
else
	print_test_result "Helpful message shown when no recent commands found" "FAIL" "Expected helpful message"
fi

# Test 28: Before offset calculation
test_history=$(mktemp)
cat >"$test_history" <<EOF
#$((current_ts - 7200))
command 2 hours ago
#$((current_ts - 3900))
command 65 minutes ago
#$((current_ts - 3600))
command 1 hour ago
#$((current_ts - 120))
command 2 minutes ago
EOF

# Test -t 30m -b 1h (30 minutes starting from 1 hour ago)
# Should find commands between 1h30m ago and 1h ago
result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" -t 30m -b 1h 2>&1 | grep -c "command 65 minutes ago")
rm -f "$test_history"
if [ "$result" -eq 1 ]; then
	print_test_result "Before offset correctly filters time range" "PASS"
else
	print_test_result "Before offset correctly filters time range" "FAIL" "Expected to find command from 65 min ago"
fi

# Test 29: Context view with -g flag (default 5 commands)
current_ts=$(date +%s)
test_history=$(mktemp)
cat >"$test_history" <<EOF
#$((current_ts - 500))
command 100
#$((current_ts - 400))
command 101
#$((current_ts - 300))
command 102
#$((current_ts - 200))
command 103
#$((current_ts - 100))
command 104
EOF

result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" -g 3 2>&1 | grep -c "command 10")
rm -f "$test_history"
if [ "$result" -ge 4 ]; then
	print_test_result "Context view shows commands around target (-g)" "PASS"
else
	print_test_result "Context view shows commands around target (-g)" "FAIL" "Expected to see context commands"
fi

# Test 30: Context view with custom size (7 commands)
test_history=$(mktemp)
for i in {1..10}; do
	echo "#$((current_ts - (1000 - i * 100)))" >>"$test_history"
	echo "command $i" >>"$test_history"
done

# Count lines that look like command output (number followed by text or ► symbol)
result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" 7 -g 5 2>&1 | grep -cE "(►\s+[0-9]+|^\s+[0-9]+\s+20)" || echo "0")
rm -f "$test_history"
result=$(echo "$result" | tr -d ' ') # Remove whitespace
if [ "$result" -eq 7 ]; then
	print_test_result "Context view respects custom size (7 -g 5)" "PASS"
else
	print_test_result "Context view respects custom size (7 -g 5)" "FAIL" "Expected 7 commands, got $result"
fi

# Test 31: Target command is highlighted
test_history=$(mktemp)
cat >"$test_history" <<EOF
#$((current_ts - 300))
before command
#$((current_ts - 200))
target command
#$((current_ts - 100))
after command
EOF

result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" -g 2 2>&1 | grep -c "►")
rm -f "$test_history"
if [ "$result" -eq 1 ]; then
	print_test_result "Target command is highlighted with ► symbol" "PASS"
else
	print_test_result "Target command is highlighted with ► symbol" "FAIL" "Expected 1 highlighted line"
fi

# Test 32: Find with count limit
current_ts=$(date +%s)
test_history=$(mktemp)
for i in {1..20}; do
	echo "#$((current_ts - (2000 - i * 100)))" >>"$test_history"
	if [ $((i % 3)) -eq 0 ]; then
		echo "git commit -m 'test $i'" >>"$test_history"
	else
		echo "other command $i" >>"$test_history"
	fi
done

result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" 3 -f "git commit" 2>&1 | grep -c "git commit -m")
rm -f "$test_history"
if [ "$result" -eq 3 ]; then
	print_test_result "Find with count limit (3 -f 'git commit')" "PASS"
else
	print_test_result "Find with count limit (3 -f 'git commit')" "FAIL" "Expected 3 results, got $result"
fi

# Test 33: Find without limit shows all matches
test_history=$(mktemp)
for i in {1..10}; do
	echo "#$((current_ts - (1000 - i * 100)))" >>"$test_history"
	if [ $((i % 2)) -eq 0 ]; then
		echo "docker ps" >>"$test_history"
	else
		echo "other command" >>"$test_history"
	fi
done

result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" -f "docker ps" 2>&1 | grep -c "^\s*docker ps" || echo "0")
rm -f "$test_history"
result=$(echo "$result" | tr -d ' ')
if [ "$result" -eq 5 ]; then
	print_test_result "Find without limit shows all matches" "PASS"
else
	print_test_result "Find without limit shows all matches" "FAIL" "Expected 5 results, got $result"
fi

# Test 34: Find shows summary with limit
test_history=$(mktemp)
for i in {1..15}; do
	echo "#$((current_ts - (1500 - i * 100)))" >>"$test_history"
	echo "test command $i" >>"$test_history"
done

result=$(HISTFILE="$test_history" HISTTIMEFORMAT='%F %T  ' bash "$HISTORY_SCRIPT" 5 -f "test command" 2>&1 | grep -c "Showing last 5 of 15")
rm -f "$test_history"
if [ "$result" -eq 1 ]; then
	print_test_result "Find shows 'Showing last X of Y' summary" "PASS"
else
	print_test_result "Find shows 'Showing last X of Y' summary" "FAIL" "Expected summary message"
fi

echo ""
