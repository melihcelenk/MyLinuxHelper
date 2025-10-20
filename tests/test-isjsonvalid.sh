#!/usr/bin/env bash
# test-isjsonvalid.sh - Test suite for isjsonvalid.sh

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/isjsonvalid.sh"

# ============================================================
# CATEGORY 1: Script Validation
# ============================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
	print_test_result "isjsonvalid.sh exists" "PASS"
else
	print_test_result "isjsonvalid.sh exists" "FAIL"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
	print_test_result "isjsonvalid.sh has valid syntax" "PASS"
else
	print_test_result "isjsonvalid.sh has valid syntax" "FAIL"
fi

# Test 3: Script is executable
if [ -x "$PLUGIN_SCRIPT" ]; then
	print_test_result "isjsonvalid.sh is executable" "PASS"
else
	print_test_result "isjsonvalid.sh is executable" "FAIL"
fi

# ============================================================
# CATEGORY 2: Help & Documentation
# ============================================================

# Test 4: Help flag works (--help)
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Usage: isjsonvalid"; then
	print_test_result "Help flag (--help) works" "PASS"
else
	print_test_result "Help flag (--help) works" "FAIL"
fi

# Test 5: Help flag works (-h)
if bash "$PLUGIN_SCRIPT" -h 2>&1 | grep -q "Usage: isjsonvalid"; then
	print_test_result "Help flag (-h) works" "PASS"
else
	print_test_result "Help flag (-h) works" "FAIL"
fi

# Test 6: Help documents detail mode
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "\-d.*detail"; then
	print_test_result "Help documents -d/--detail flag" "PASS"
else
	print_test_result "Help documents -d/--detail flag" "FAIL"
fi

# Test 7: Help contains examples
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Examples:"; then
	print_test_result "Help contains usage examples" "PASS"
else
	print_test_result "Help contains usage examples" "FAIL"
fi

# ============================================================
# CATEGORY 3: Script Structure
# ============================================================

# Test 8: Script uses jq for validation
if grep -q "jq" "$PLUGIN_SCRIPT"; then
	print_test_result "Script uses jq for validation" "PASS"
else
	print_test_result "Script uses jq for validation" "FAIL"
fi

# Test 9: Script has symlink resolution logic
if grep -q "readlink" "$PLUGIN_SCRIPT"; then
	print_test_result "Script has symlink resolution logic" "PASS"
else
	print_test_result "Script has symlink resolution logic" "FAIL"
fi

# Test 10: Script sources install.sh
if grep -q "install.sh" "$PLUGIN_SCRIPT"; then
	print_test_result "Script sources install.sh for jq" "PASS"
else
	print_test_result "Script sources install.sh for jq" "FAIL"
fi

# ============================================================
# CATEGORY 4: Validation Modes
# ============================================================

# Test 11: Script has DETAIL_MODE variable
if grep -q "DETAIL_MODE" "$PLUGIN_SCRIPT"; then
	print_test_result "Script supports detail mode" "PASS"
else
	print_test_result "Script supports detail mode" "FAIL"
fi

# Test 12: Script outputs "Yes" for valid JSON (simple mode)
if grep -q 'echo "Yes"' "$PLUGIN_SCRIPT"; then
	print_test_result "Script outputs 'Yes' for valid JSON" "PASS"
else
	print_test_result "Script outputs 'Yes' for valid JSON" "FAIL"
fi

# Test 13: Script outputs "No" for invalid JSON (simple mode)
if grep -q 'echo "No"' "$PLUGIN_SCRIPT"; then
	print_test_result "Script outputs 'No' for invalid JSON" "PASS"
else
	print_test_result "Script outputs 'No' for invalid JSON" "FAIL"
fi

# Test 14: Script has colored output for detail mode
if grep -q "Valid JSON" "$PLUGIN_SCRIPT" && grep -q "Invalid JSON" "$PLUGIN_SCRIPT"; then
	print_test_result "Script has detailed validation messages" "PASS"
else
	print_test_result "Script has detailed validation messages" "FAIL"
fi

# ============================================================
# CATEGORY 5: Error Handling
# ============================================================

# Test 15: Script checks if file exists
if grep -q "not found" "$PLUGIN_SCRIPT"; then
	print_test_result "Script validates file existence" "PASS"
else
	print_test_result "Script validates file existence" "FAIL"
fi

# Test 16: Script checks if file argument is provided
if grep -q "no file specified" "$PLUGIN_SCRIPT"; then
	print_test_result "Error shown when no file specified" "PASS"
else
	print_test_result "Error shown when no file specified" "FAIL"
fi

# Test 17: Script checks for jq availability
if grep -q "command -v jq" "$PLUGIN_SCRIPT"; then
	print_test_result "Script checks for jq availability" "PASS"
else
	print_test_result "Script checks for jq availability" "FAIL"
fi

# Test 18: Script has color definitions
if grep -q "GREEN=" "$PLUGIN_SCRIPT" &&
	grep -q "RED=" "$PLUGIN_SCRIPT" &&
	grep -q "YELLOW=" "$PLUGIN_SCRIPT"; then
	print_test_result "Script defines color codes" "PASS"
else
	print_test_result "Script defines color codes" "FAIL"
fi
