#!/usr/bin/env bash
# test-mlh.sh - Test suite for mlh.sh (main dispatcher)

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/mlh.sh"

# ============================================================
# CATEGORY 1: Script Validation
# ============================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
	print_test_result "mlh.sh exists" "PASS"
else
	print_test_result "mlh.sh exists" "FAIL"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
	print_test_result "mlh.sh has valid syntax" "PASS"
else
	print_test_result "mlh.sh has valid syntax" "FAIL"
fi

# Test 3: Script is executable
if [ -x "$PLUGIN_SCRIPT" ]; then
	print_test_result "mlh.sh is executable" "PASS"
else
	print_test_result "mlh.sh is executable" "FAIL"
fi

# ============================================================
# CATEGORY 2: Help & Documentation
# ============================================================

# Test 4: Help flag works (--help)
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "mlh - MyLinuxHelper shortcut commands"; then
	print_test_result "Help flag (--help) works" "PASS"
else
	print_test_result "Help flag (--help) works" "FAIL"
fi

# Test 5: Help flag works (-h)
if bash "$PLUGIN_SCRIPT" -h 2>&1 | grep -q "mlh - MyLinuxHelper shortcut commands"; then
	print_test_result "Help flag (-h) works" "PASS"
else
	print_test_result "Help flag (-h) works" "FAIL"
fi

# Test 6: Help contains categories
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Categories:"; then
	print_test_result "Help documents categories" "PASS"
else
	print_test_result "Help documents categories" "FAIL"
fi

# Test 7: Help contains examples
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Examples:"; then
	print_test_result "Help contains usage examples" "PASS"
else
	print_test_result "Help contains usage examples" "FAIL"
fi

# ============================================================
# CATEGORY 3: Category Routing
# ============================================================

# Test 8: Script references mlh-docker.sh
if grep -q "mlh-docker.sh" "$PLUGIN_SCRIPT"; then
	print_test_result "Script routes to mlh-docker.sh" "PASS"
else
	print_test_result "Script routes to mlh-docker.sh" "FAIL"
fi

# Test 9: Script references mlh-json.sh
if grep -q "mlh-json.sh" "$PLUGIN_SCRIPT"; then
	print_test_result "Script routes to mlh-json.sh" "PASS"
else
	print_test_result "Script routes to mlh-json.sh" "FAIL"
fi

# Test 10: Script references mlh-history.sh
if grep -q "mlh-history.sh" "$PLUGIN_SCRIPT"; then
	print_test_result "Script routes to mlh-history.sh" "PASS"
else
	print_test_result "Script routes to mlh-history.sh" "FAIL"
fi

# Test 11: Script has 'docker' case
if grep -q 'docker)' "$PLUGIN_SCRIPT"; then
	print_test_result "Script has 'docker' category case" "PASS"
else
	print_test_result "Script has 'docker' category case" "FAIL"
fi

# Test 12: Script has 'json' case
if grep -q 'json)' "$PLUGIN_SCRIPT"; then
	print_test_result "Script has 'json' category case" "PASS"
else
	print_test_result "Script has 'json' category case" "FAIL"
fi

# Test 13: Script has 'history' case
if grep -q 'history)' "$PLUGIN_SCRIPT"; then
	print_test_result "Script has 'history' category case" "PASS"
else
	print_test_result "Script has 'history' category case" "FAIL"
fi

# Test 14: Script has 'about' case
if grep -q 'about)' "$PLUGIN_SCRIPT"; then
	print_test_result "Script has 'about' category case" "PASS"
else
	print_test_result "Script has 'about' category case" "FAIL"
fi

# Test 15: Script has 'update' case
if grep -q 'update)' "$PLUGIN_SCRIPT"; then
	print_test_result "Script has 'update' category case" "PASS"
else
	print_test_result "Script has 'update' category case" "FAIL"
fi

# ============================================================
# CATEGORY 4: Error Handling
# ============================================================

# Test 16: Script handles unknown categories
if grep -q "Unknown category" "$PLUGIN_SCRIPT"; then
	print_test_result "Error shown for unknown categories" "PASS"
else
	print_test_result "Error shown for unknown categories" "FAIL"
fi

# Test 17: Version flag works
if grep -q "mlh-version.sh" "$PLUGIN_SCRIPT"; then
	print_test_result "Script delegates to mlh-version.sh" "PASS"
else
	print_test_result "Script delegates to mlh-version.sh" "FAIL"
fi

# ============================================================
# CATEGORY 5: Interactive Menu
# ============================================================

# Test 18: Script has interactive menu function
if grep -q "show_interactive_menu" "$PLUGIN_SCRIPT"; then
	print_test_result "Script has interactive menu function" "PASS"
else
	print_test_result "Script has interactive menu function" "FAIL"
fi

# Test 19: Interactive menu references major commands
MENU_CONTENT=$(grep -A 20 "show_interactive_menu" "$PLUGIN_SCRIPT" | head -30)
if echo "$MENU_CONTENT" | grep -q "linux" &&
	echo "$MENU_CONTENT" | grep -q "search" &&
	echo "$MENU_CONTENT" | grep -q "JSON" &&
	echo "$MENU_CONTENT" | grep -q "docker" &&
	echo "$MENU_CONTENT" | grep -q "history"; then
	print_test_result "Interactive menu lists all major commands" "PASS"
else
	print_test_result "Interactive menu lists all major commands" "FAIL"
fi

# Test 20: Script has symlink resolution function
if grep -q "resolve_script_dir" "$PLUGIN_SCRIPT"; then
	print_test_result "Script has symlink resolution logic" "PASS"
else
	print_test_result "Script has symlink resolution logic" "FAIL"
fi
