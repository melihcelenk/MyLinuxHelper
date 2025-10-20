#!/usr/bin/env bash
# test-mlh-json.sh - Test suite for mlh-json.sh

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/mlh-json.sh"

# Check if jq is available
JQ_AVAILABLE=0
if command -v jq >/dev/null 2>&1; then
  JQ_AVAILABLE=1
fi

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
  print_test_result "mlh-json.sh exists" "PASS"
else
  print_test_result "mlh-json.sh exists" "FAIL" "File not found at: $PLUGIN_SCRIPT"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
  print_test_result "mlh-json.sh has valid syntax" "PASS"
else
  print_test_result "mlh-json.sh has valid syntax" "FAIL" "Syntax errors found"
fi

# Test 3: Help text works
if bash "$PLUGIN_SCRIPT" --help >/dev/null 2>&1; then
  print_test_result "mlh json --help works" "PASS"
else
  print_test_result "mlh json --help works" "FAIL" "Help command failed"
fi

# Create test data directory
TEST_DATA_DIR=$(mktemp -d)

# Test 4: Valid JSON file validation
cat > "$TEST_DATA_DIR/valid.json" << 'EOF'
{
  "users": [
    {"name": "John", "age": 30},
    {"name": "Jane", "age": 25}
  ],
  "settings": {
    "language": "en",
    "theme": "dark"
  }
}
EOF

if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "Valid JSON file recognized" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/valid.json" 2>&1 | grep -c "Valid JSON")
  if [ "$result" -eq 1 ]; then
    print_test_result "Valid JSON file recognized" "PASS"
  else
    print_test_result "Valid JSON file recognized" "FAIL" "Expected 'Valid JSON' message"
  fi
fi

# Test 5: Invalid JSON file validation
cat > "$TEST_DATA_DIR/invalid.json" << 'EOF'
{
  "users": [
    {"name": "John", "age": 30},
    {"name": "Jane", "age": 25
  }
}
EOF

result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/invalid.json" 2>&1)
if echo "$result" | grep -q "Invalid JSON\|parse error\|Error"; then
  print_test_result "Invalid JSON file detected" "PASS"
else
  print_test_result "Invalid JSON file detected" "FAIL" "Should detect invalid JSON"
fi

# Test 6: Non-existent file handling
if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "Non-existent file error message" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/nonexistent.json" 2>&1)
  if echo "$result" | grep -qi "not found\|does not exist\|No such file"; then
    print_test_result "Non-existent file error message" "PASS"
  else
    print_test_result "Non-existent file error message" "FAIL" "Should show file not found error"
  fi
fi

# Test 7: Empty JSON file
echo "{}" > "$TEST_DATA_DIR/empty.json"
if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "Empty JSON object is valid" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/empty.json" 2>&1 | grep -c "Valid JSON")
  if [ "$result" -eq 1 ]; then
    print_test_result "Empty JSON object is valid" "PASS"
  else
    print_test_result "Empty JSON object is valid" "FAIL" "Empty {} should be valid"
  fi
fi

# Test 8: JSON array
echo '[1, 2, 3]' > "$TEST_DATA_DIR/array.json"
if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "JSON array is valid" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/array.json" 2>&1 | grep -c "Valid JSON")
  if [ "$result" -eq 1 ]; then
    print_test_result "JSON array is valid" "PASS"
  else
    print_test_result "JSON array is valid" "FAIL" "Arrays should be valid JSON"
  fi
fi

# Test 9: JSON search - exact key match
cat > "$TEST_DATA_DIR/search.json" << 'EOF'
{
  "username": "john_doe",
  "email": "john@example.com",
  "profile": {
    "age": 30,
    "city": "New York"
  }
}
EOF

if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "JSON search finds exact key" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" get username from "$TEST_DATA_DIR/search.json" 2>&1 | grep -c "username")
  if [ "$result" -ge 1 ]; then
    print_test_result "JSON search finds exact key" "PASS"
  else
    print_test_result "JSON search finds exact key" "FAIL" "Should find 'username' key"
  fi
fi

# Test 10: JSON search - nested key
result=$(bash "$PLUGIN_SCRIPT" get age from "$TEST_DATA_DIR/search.json" 2>&1 | grep -c "age")
if [ "$result" -ge 1 ]; then
  print_test_result "JSON search finds nested key" "PASS"
else
  print_test_result "JSON search finds nested key" "FAIL" "Should find nested 'age' key"
fi

# Test 11: JSON search - fuzzy match
cat > "$TEST_DATA_DIR/fuzzy.json" << 'EOF'
{
  "RequestedTags": ["tag1", "tag2"],
  "ResponseCode": 200
}
EOF

if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "JSON search fuzzy matching works" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" get req from "$TEST_DATA_DIR/fuzzy.json" 2>&1 | grep -c "Requested")
  if [ "$result" -ge 1 ]; then
    print_test_result "JSON search fuzzy matching works" "PASS"
  else
    print_test_result "JSON search fuzzy matching works" "FAIL" "Should find 'RequestedTags' with 'req'"
  fi
fi

# Test 12: JSON search - no matches
if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "JSON search handles no matches" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" get nonexistentkey from "$TEST_DATA_DIR/search.json" 2>&1)
  if echo "$result" | grep -qi "not found\|no matches"; then
    print_test_result "JSON search handles no matches" "PASS"
  else
    print_test_result "JSON search handles no matches" "FAIL" "Should indicate no matches found"
  fi
fi

# Test 13: Help contains search examples
help_output=$(bash "$PLUGIN_SCRIPT" --help 2>&1)
if echo "$help_output" | grep -q "get.*from"; then
  print_test_result "Help contains search examples" "PASS"
else
  print_test_result "Help contains search examples" "FAIL" "Help should show search syntax"
fi

# Test 14: Help contains validation examples
if echo "$help_output" | grep -q "isvalid\|--isvalid"; then
  print_test_result "Help contains validation examples" "PASS"
else
  print_test_result "Help contains validation examples" "FAIL" "Help should show validation syntax"
fi

# Test 15: Large JSON file (performance test)
cat > "$TEST_DATA_DIR/large.json" << 'EOF'
{
  "data": [
EOF
for i in {1..100}; do
  echo "    {\"id\": $i, \"value\": \"item$i\"}," >> "$TEST_DATA_DIR/large.json"
done
cat >> "$TEST_DATA_DIR/large.json" << 'EOF'
    {"id": 101, "value": "item101"}
  ]
}
EOF

start_time=$(date +%s)
bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/large.json" >/dev/null 2>&1
end_time=$(date +%s)
duration=$((end_time - start_time))

if [ "$duration" -lt 5 ]; then
  print_test_result "Large JSON validation performance (<5s)" "PASS"
else
  print_test_result "Large JSON validation performance (<5s)" "FAIL" "Took ${duration}s, should be <5s"
fi

# Test 16: JSON with special characters
cat > "$TEST_DATA_DIR/special.json" << 'EOF'
{
  "message": "Hello \"World\"",
  "path": "/usr/local/bin",
  "unicode": "你好"
}
EOF

if [ "$JQ_AVAILABLE" -eq 0 ]; then
  print_test_result "JSON with special characters is valid" "SKIP" "jq not installed"
else
  result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/special.json" 2>&1 | grep -c "Valid JSON")
  if [ "$result" -eq 1 ]; then
    print_test_result "JSON with special characters is valid" "PASS"
  else
    print_test_result "JSON with special characters is valid" "FAIL" "Should handle special chars"
  fi
fi

# Test 17: JSON search with path hint
result=$(bash "$PLUGIN_SCRIPT" get profile.age from "$TEST_DATA_DIR/search.json" 2>&1 | grep -c "age")
if [ "$result" -ge 1 ]; then
  print_test_result "JSON search with path hint works" "PASS"
else
  print_test_result "JSON search with path hint works" "FAIL" "Should find with path hint"
fi

# Test 18: Malformed JSON with trailing comma
cat > "$TEST_DATA_DIR/trailing.json" << 'EOF'
{
  "key1": "value1",
  "key2": "value2",
}
EOF

result=$(bash "$PLUGIN_SCRIPT" --isvalid "$TEST_DATA_DIR/trailing.json" 2>&1)
if echo "$result" | grep -q "Invalid JSON\|parse error\|Error"; then
  print_test_result "Detects trailing comma error" "PASS"
else
  print_test_result "Detects trailing comma error" "FAIL" "Should detect trailing comma"
fi

# Cleanup
rm -rf "$TEST_DATA_DIR"

echo ""
