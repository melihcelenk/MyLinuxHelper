#!/usr/bin/env bash
# test-search.sh - Test suite for search.sh

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/search.sh"

# ============================================================
# CATEGORY 1: Script Validation
# ============================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
	print_test_result "search.sh exists" "PASS"
else
	print_test_result "search.sh exists" "FAIL"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
	print_test_result "search.sh has valid syntax" "PASS"
else
	print_test_result "search.sh has valid syntax" "FAIL"
fi

# Test 3: Script is executable
if [ -x "$PLUGIN_SCRIPT" ]; then
	print_test_result "search.sh is executable" "PASS"
else
	print_test_result "search.sh is executable" "FAIL"
fi

# ============================================================
# CATEGORY 2: Help & Documentation
# ============================================================

# Test 4: Help flag works (--help)
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Usage: search"; then
	print_test_result "Help flag (--help) works" "PASS"
else
	print_test_result "Help flag (--help) works" "FAIL"
fi

# Test 5: Help flag works (-h)
if bash "$PLUGIN_SCRIPT" -h 2>&1 | grep -q "Usage: search"; then
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

# Test 7: Help documents pattern argument
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "pattern"; then
	print_test_result "Help documents pattern argument" "PASS"
else
	print_test_result "Help documents pattern argument" "FAIL"
fi

# ============================================================
# CATEGORY 3: Search Logic & Structure
# ============================================================

# Test 8: Script uses find command
if grep -q "find" "$PLUGIN_SCRIPT"; then
	print_test_result "Script uses find command" "PASS"
else
	print_test_result "Script uses find command" "FAIL"
fi

# Test 9: Script handles wildcards
if grep -q '\*' "$PLUGIN_SCRIPT"; then
	print_test_result "Script handles wildcard patterns" "PASS"
else
	print_test_result "Script handles wildcard patterns" "FAIL"
fi

# Test 10: Script uses -iname for case-insensitive search
if grep -q "iname" "$PLUGIN_SCRIPT"; then
	print_test_result "Script supports case-insensitive search" "PASS"
else
	print_test_result "Script supports case-insensitive search" "FAIL"
fi

# Test 11: Script checks if directory exists
if grep -q "does not exist" "$PLUGIN_SCRIPT"; then
	print_test_result "Script validates directory existence" "PASS"
else
	print_test_result "Script validates directory existence" "FAIL"
fi

# Test 12: Script handles no results
if grep -q "No files found" "$PLUGIN_SCRIPT"; then
	print_test_result "Script handles no results found" "PASS"
else
	print_test_result "Script handles no results found" "FAIL"
fi

# ============================================================
# CATEGORY 4: Error Handling
# ============================================================

# Test 13: Script checks for pattern argument
HELP_OUTPUT=$(bash "$PLUGIN_SCRIPT" 2>&1)
if echo "$HELP_OUTPUT" | grep -q "Usage: search"; then
	print_test_result "Shows help when no arguments provided" "PASS"
else
	print_test_result "Shows help when no arguments provided" "FAIL"
fi

# Test 14: Script has error handling for invalid paths
if grep -q 'Error:.*does not exist' "$PLUGIN_SCRIPT"; then
	print_test_result "Error handling for invalid paths" "PASS"
else
	print_test_result "Error handling for invalid paths" "FAIL"
fi

# ============================================================
# CATEGORY 5: Output Format
# ============================================================

# Test 15: Script shows search location message
if grep -q "Searching for" "$PLUGIN_SCRIPT"; then
	print_test_result "Script shows search location message" "PASS"
else
	print_test_result "Script shows search location message" "FAIL"
fi

# Test 16: Script displays result count
if grep -q "Found.*file" "$PLUGIN_SCRIPT"; then
	print_test_result "Script displays result count" "PASS"
else
	print_test_result "Script displays result count" "FAIL"
fi
