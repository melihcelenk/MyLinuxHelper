#!/usr/bin/env bash
# test-mlh-about.sh - Test suite for mlh-about.sh

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/mlh-about.sh"

# ============================================================
# CATEGORY 1: Script Validation
# ============================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
  print_test_result "mlh-about.sh exists" "PASS"
else
  print_test_result "mlh-about.sh exists" "FAIL"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
  print_test_result "mlh-about.sh has valid syntax" "PASS"
else
  print_test_result "mlh-about.sh has valid syntax" "FAIL"
fi

# Test 3: Script is executable
if [ -x "$PLUGIN_SCRIPT" ]; then
  print_test_result "mlh-about.sh is executable" "PASS"
else
  print_test_result "mlh-about.sh is executable" "FAIL"
fi

# ============================================================
# CATEGORY 2: Content & Structure
# ============================================================

# Test 4: Script has show_about function
if grep -q "show_about" "$PLUGIN_SCRIPT"; then
  print_test_result "Script has show_about function" "PASS"
else
  print_test_result "Script has show_about function" "FAIL"
fi

# Test 5: Script displays project name
if grep -q "MyLinuxHelper" "$PLUGIN_SCRIPT"; then
  print_test_result "Script displays project name" "PASS"
else
  print_test_result "Script displays project name" "FAIL"
fi

# Test 6: Script displays author information
if grep -q "Author:" "$PLUGIN_SCRIPT" || grep -q "Melih" "$PLUGIN_SCRIPT"; then
  print_test_result "Script displays author information" "PASS"
else
  print_test_result "Script displays author information" "FAIL"
fi

# Test 7: Script displays GitHub link
if grep -q "github.com" "$PLUGIN_SCRIPT"; then
  print_test_result "Script displays GitHub link" "PASS"
else
  print_test_result "Script displays GitHub link" "FAIL"
fi

# Test 8: Script displays version information
if grep -q "Version" "$PLUGIN_SCRIPT" || grep -q "version" "$PLUGIN_SCRIPT"; then
  print_test_result "Script displays version information" "PASS"
else
  print_test_result "Script displays version information" "FAIL"
fi

# ============================================================
# CATEGORY 3: Features & Integration
# ============================================================

# Test 9: Script has symlink resolution logic
if grep -q "resolve_script_dir" "$PLUGIN_SCRIPT"; then
  print_test_result "Script has symlink resolution logic" "PASS"
else
  print_test_result "Script has symlink resolution logic" "FAIL"
fi

# Test 10: Script supports --no-prompt flag
if grep -q "no-prompt" "$PLUGIN_SCRIPT"; then
  print_test_result "Script supports --no-prompt flag" "PASS"
else
  print_test_result "Script supports --no-prompt flag" "FAIL"
fi

# Test 11: Script lists features
if grep -q "Features:" "$PLUGIN_SCRIPT"; then
  print_test_result "Script lists project features" "PASS"
else
  print_test_result "Script lists project features" "FAIL"
fi

# Test 12: Script references mlh-version.sh for version info
if grep -q "mlh-version.sh" "$PLUGIN_SCRIPT"; then
  print_test_result "Script integrates with mlh-version.sh" "PASS"
else
  print_test_result "Script integrates with mlh-version.sh" "FAIL"
fi
