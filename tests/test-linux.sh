#!/usr/bin/env bash
# test-linux.sh - Test suite for linux.sh

set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/linux.sh"

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
  print_test_result "linux.sh exists" "PASS"
else
  print_test_result "linux.sh exists" "FAIL" "File not found"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
  print_test_result "linux.sh has valid syntax" "PASS"
else
  print_test_result "linux.sh has valid syntax" "FAIL"
fi

# Test 3: Help text works
if bash "$PLUGIN_SCRIPT" --help >/dev/null 2>&1; then
  print_test_result "linux --help works" "PASS"
else
  print_test_result "linux --help works" "FAIL"
fi

# Test 4: Help contains examples
help_output=$(bash "$PLUGIN_SCRIPT" --help 2>&1)
if echo "$help_output" | grep -q "linux mycontainer"; then
  print_test_result "Help contains usage examples" "PASS"
else
  print_test_result "Help contains usage examples" "FAIL"
fi

# Test 5: Help mentions -p flag (persistent)
if echo "$help_output" | grep -q "\-p"; then
  print_test_result "Help documents -p flag" "PASS"
else
  print_test_result "Help documents -p flag" "FAIL"
fi

# Test 6: Help mentions -s flag (stop)
if echo "$help_output" | grep -q "\-s"; then
  print_test_result "Help documents -s flag" "PASS"
else
  print_test_result "Help documents -s flag" "FAIL"
fi

# Test 7: Help mentions -d flag (delete)
if echo "$help_output" | grep -q "\-d"; then
  print_test_result "Help documents -d flag" "PASS"
else
  print_test_result "Help documents -d flag" "FAIL"
fi

# Test 8: Help mentions -i flag (image)
if echo "$help_output" | grep -q "\-i"; then
  print_test_result "Help documents -i flag" "PASS"
else
  print_test_result "Help documents -i flag" "FAIL"
fi

# Test 9: Help mentions -m flag (mount)
if echo "$help_output" | grep -q "\-m"; then
  print_test_result "Help documents -m flag" "PASS"
else
  print_test_result "Help documents -m flag" "FAIL"
fi

# Test 10: Error when no container name provided
result=$(bash "$PLUGIN_SCRIPT" 2>&1)
if echo "$result" | grep -qi "usage\|error\|required"; then
  print_test_result "Error shown when no container name" "PASS"
else
  print_test_result "Error shown when no container name" "FAIL"
fi

# Test 11: Script defines default image
if grep -q "ubuntu:24.04\|ubuntu:latest\|DEFAULT_IMAGE" "$PLUGIN_SCRIPT"; then
  print_test_result "Script defines default image" "PASS"
else
  print_test_result "Script defines default image" "FAIL"
fi

# Test 12: Script has flag parsing logic
if grep -q "case.*\$1.*in" "$PLUGIN_SCRIPT"; then
  print_test_result "Script has argument parsing" "PASS"
else
  print_test_result "Script has argument parsing" "FAIL"
fi

# Test 13: Script checks for Docker
if grep -q "docker\|command.*docker" "$PLUGIN_SCRIPT"; then
  print_test_result "Script references Docker commands" "PASS"
else
  print_test_result "Script references Docker commands" "FAIL"
fi

# Test 14: Ephemeral mode uses --rm flag
if grep -q "\-\-rm" "$PLUGIN_SCRIPT"; then
  print_test_result "Ephemeral mode uses --rm flag" "PASS"
else
  print_test_result "Ephemeral mode uses --rm flag" "FAIL"
fi

# Test 15: Interactive mode uses -it flags
if grep -q "\-it\|\-i.*\-t" "$PLUGIN_SCRIPT"; then
  print_test_result "Interactive mode uses -it flags" "PASS"
else
  print_test_result "Interactive mode uses -it flags" "FAIL"
fi

echo ""
