#!/usr/bin/env bash
# test-ll.sh - Test suite for ll.sh

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/ll.sh"

# ============================================================
# CATEGORY 1: Script Validation
# ============================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
	print_test_result "ll.sh exists" "PASS"
else
	print_test_result "ll.sh exists" "FAIL"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
	print_test_result "ll.sh has valid syntax" "PASS"
else
	print_test_result "ll.sh has valid syntax" "FAIL"
fi

# Test 3: Script is executable
if [ -x "$PLUGIN_SCRIPT" ]; then
	print_test_result "ll.sh is executable" "PASS"
else
	print_test_result "ll.sh is executable" "FAIL"
fi

# ============================================================
# CATEGORY 2: Help & Documentation
# ============================================================

# Test 4: Help flag works (--help)
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Usage: ll"; then
	print_test_result "Help flag (--help) works" "PASS"
else
	print_test_result "Help flag (--help) works" "FAIL"
fi

# Test 5: Help flag works (-h)
if bash "$PLUGIN_SCRIPT" -h 2>&1 | grep -q "Usage: ll"; then
	print_test_result "Help flag (-h) works" "PASS"
else
	print_test_result "Help flag (-h) works" "FAIL"
fi

# Test 6: Help contains examples
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Examples:"; then
	print_test_result "Help contains usage examples" "PASS"
else
	print_test_result "Help contains usage examples" "FAIL"
fi

# Test 7: Help describes it as shortcut for ls -la
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "ls -la"; then
	print_test_result "Help describes ls -la functionality" "PASS"
else
	print_test_result "Help describes ls -la functionality" "FAIL"
fi

# ============================================================
# CATEGORY 3: Functionality
# ============================================================

# Test 8: Script uses ls -la command
if grep -q "ls -la" "$PLUGIN_SCRIPT"; then
	print_test_result "Script uses 'ls -la' command" "PASS"
else
	print_test_result "Script uses 'ls -la' command" "FAIL"
fi

# Test 9: Script passes arguments to ls
if grep -q 'ls -la "\$@"' "$PLUGIN_SCRIPT"; then
	print_test_result "Script passes arguments to ls" "PASS"
else
	print_test_result "Script passes arguments to ls" "FAIL"
fi

# Test 10: Script is simple wrapper (under 20 lines)
LINE_COUNT=$(wc -l <"$PLUGIN_SCRIPT")
if [ "$LINE_COUNT" -lt 30 ]; then
	print_test_result "Script is simple and concise (<30 lines)" "PASS"
else
	print_test_result "Script is simple and concise (<30 lines)" "FAIL"
fi
