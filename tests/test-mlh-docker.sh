#!/usr/bin/env bash
# test-mlh-docker.sh - Test suite for mlh-docker.sh

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/mlh-docker.sh"

# ============================================================
# CATEGORY 1: Script Validation
# ============================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
  print_test_result "mlh-docker.sh exists" "PASS"
else
  print_test_result "mlh-docker.sh exists" "FAIL"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
  print_test_result "mlh-docker.sh has valid syntax" "PASS"
else
  print_test_result "mlh-docker.sh has valid syntax" "FAIL"
fi

# Test 3: Script is executable
if [ -x "$PLUGIN_SCRIPT" ]; then
  print_test_result "mlh-docker.sh is executable" "PASS"
else
  print_test_result "mlh-docker.sh is executable" "FAIL"
fi

# ============================================================
# CATEGORY 2: Help & Documentation
# ============================================================

# Test 4: Help flag works
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "mlh docker - Docker shortcuts"; then
  print_test_result "Help flag (--help) works" "PASS"
else
  print_test_result "Help flag (--help) works" "FAIL"
fi

# Test 5: Help contains 'in' command
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "in <pattern>"; then
  print_test_result "Help documents 'in' command" "PASS"
else
  print_test_result "Help documents 'in' command" "FAIL"
fi

# Test 6: Help contains usage examples
if bash "$PLUGIN_SCRIPT" --help 2>&1 | grep -q "Examples:"; then
  print_test_result "Help contains usage examples" "PASS"
else
  print_test_result "Help contains usage examples" "FAIL"
fi

# Test 7: -h flag works (short form)
if bash "$PLUGIN_SCRIPT" -h 2>&1 | grep -q "mlh docker - Docker shortcuts"; then
  print_test_result "Help flag (-h) works" "PASS"
else
  print_test_result "Help flag (-h) works" "FAIL"
fi

# ============================================================
# CATEGORY 3: Command Structure & Error Handling
# ============================================================

# Test 8: Script checks for docker command
if grep -q "command -v docker" "$PLUGIN_SCRIPT"; then
  print_test_result "Script checks for docker availability" "PASS"
else
  print_test_result "Script checks for docker availability" "FAIL"
fi

# Test 9: Script has 'in' command implementation
if grep -q 'in)' "$PLUGIN_SCRIPT"; then
  print_test_result "Script has 'in' command case" "PASS"
else
  print_test_result "Script has 'in' command case" "FAIL"
fi

# Test 10: Script validates container pattern is provided
if grep -q "Missing container name pattern" "$PLUGIN_SCRIPT"; then
  print_test_result "Error shown when no pattern provided" "PASS"
else
  print_test_result "Error shown when no pattern provided" "FAIL"
fi

# Test 11: Script handles no containers found
if grep -q "No running containers found matching pattern" "$PLUGIN_SCRIPT"; then
  print_test_result "Error shown when no containers match" "PASS"
else
  print_test_result "Error shown when no containers match" "FAIL"
fi

# Test 12: Script handles unknown commands
if grep -q "Unknown command" "$PLUGIN_SCRIPT"; then
  print_test_result "Error shown for unknown commands" "PASS"
else
  print_test_result "Error shown for unknown commands" "FAIL"
fi

# ============================================================
# CATEGORY 4: Container Selection Logic
# ============================================================

# Test 13: Script uses docker ps for listing containers
if grep -q "docker ps" "$PLUGIN_SCRIPT"; then
  print_test_result "Script uses 'docker ps' to list containers" "PASS"
else
  print_test_result "Script uses 'docker ps' to list containers" "FAIL"
fi

# Test 14: Script filters containers by pattern with grep
if grep -q "grep -i.*PATTERN" "$PLUGIN_SCRIPT"; then
  print_test_result "Script filters containers with grep" "PASS"
else
  print_test_result "Script filters containers with grep" "FAIL"
fi

# Test 15: Script handles multiple container matches
if grep -q "Multiple containers found matching" "$PLUGIN_SCRIPT"; then
  print_test_result "Script shows menu for multiple matches" "PASS"
else
  print_test_result "Script shows menu for multiple matches" "FAIL"
fi

# Test 16: Script validates selection input
if grep -q 'Invalid selection' "$PLUGIN_SCRIPT"; then
  print_test_result "Script validates user selection" "PASS"
else
  print_test_result "Script validates user selection" "FAIL"
fi

# Test 17: Script uses docker exec to enter containers
if grep -q "docker exec -it" "$PLUGIN_SCRIPT"; then
  print_test_result "Script uses 'docker exec -it' to enter" "PASS"
else
  print_test_result "Script uses 'docker exec -it' to enter" "FAIL"
fi

# Test 18: Script shows container image and status info
if grep -q '{{.Image}}.*{{.Status}}' "$PLUGIN_SCRIPT"; then
  print_test_result "Script displays container image and status" "PASS"
else
  print_test_result "Script displays container image and status" "FAIL"
fi
