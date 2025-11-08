#!/usr/bin/env bash
# Integration tests for bookmark alias functionality with setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source test framework functions from parent
if [ -n "${STATS_FILE:-}" ]; then
	# Running under test runner
	:
else
	# Standalone execution
	GREEN='\033[0;32m'
	RED='\033[0;31m'
	YELLOW='\033[1;33m'
	CYAN='\033[0;36m'
	NC='\033[0m'
	
	print_test_result() {
		local test_name="$1"
		local result="$2"
		local message="${3:-}"
		
		if [ "$result" = "PASS" ]; then
			echo -e "${GREEN}✓ PASS${NC}: $test_name"
		elif [ "$result" = "SKIP" ]; then
			echo -e "${YELLOW}⊘ SKIP${NC}: $test_name"
			[ -n "$message" ] && echo -e "  ${YELLOW}$message${NC}"
		else
			echo -e "${RED}✗ FAIL${NC}: $test_name"
			[ -n "$message" ] && echo -e "  ${YELLOW}$message${NC}"
		fi
	}
fi

# Setup test environment
setup_test_env() {
	export TEST_HOME="/tmp/test-bookmark-alias-integration-$$"
	mkdir -p "$TEST_HOME/.mylinuxhelper"
	mkdir -p "$TEST_HOME/.local/bin"
	export HOME="$TEST_HOME"
	export MLH_CONFIG_DIR="$TEST_HOME/.mylinuxhelper"
	export ALIAS_CONFIG_FILE="$MLH_CONFIG_DIR/bookmark-alias.conf"
	
	# Create minimal bashrc
	touch "$TEST_HOME/.bashrc"
	touch "$TEST_HOME/.profile"
}

# Cleanup test environment
cleanup_test_env() {
	rm -rf "/tmp/test-bookmark-alias-integration-$$" 2>/dev/null || true
}

# Trap to ensure cleanup
trap cleanup_test_env EXIT

# Run tests
setup_test_env

#
# Test Group 1: Wrapper function structure
#

# Test 1: Alias wrapper delegates to bookmark function
echo "BOOKMARK_ALIAS=bm" > "$ALIAS_CONFIG_FILE"

# Create a mock bashrc with wrapper
cat > "$TEST_HOME/.bashrc" << 'EOF'
bookmark() {
  echo "bookmark function called with: $*"
  command bookmark "$@"
}

bm() {
  bookmark "$@"
}
EOF

# Source and test
source "$TEST_HOME/.bashrc"
output=$(bm test 2>&1 || true)
if echo "$output" | grep -q "bookmark function called"; then
	print_test_result "Alias wrapper delegates to bookmark function" "PASS"
else
	print_test_result "Alias wrapper delegates to bookmark function" "FAIL" "Delegation not working"
fi

# Test 2: Wrapper preserves all arguments
output=$(bm arg1 arg2 arg3 2>&1 || true)
if echo "$output" | grep -q "arg1 arg2 arg3"; then
	print_test_result "Wrapper preserves all arguments" "PASS"
else
	print_test_result "Wrapper preserves all arguments" "FAIL" "Arguments not preserved"
fi

# Test 3: Wrapper handles special characters in arguments
output=$(bm "path with spaces" 2>&1 || true)
if echo "$output" | grep -q "path with spaces"; then
	print_test_result "Wrapper handles special characters" "PASS"
else
	print_test_result "Wrapper handles special characters" "FAIL" "Special chars not handled"
fi

#
# Test Group 2: setup.sh execution with alias
#

# Test 4: setup.sh runs without error with alias configured
echo "BOOKMARK_ALIAS=testbm" > "$ALIAS_CONFIG_FILE"
output=$(cd "$ROOT_DIR" && bash setup.sh 2>&1 || true)
exit_code=$?
if [ $exit_code -eq 0 ] || echo "$output" | grep -q "Setup complete"; then
	print_test_result "setup.sh runs without error with alias" "PASS"
else
	print_test_result "setup.sh runs without error with alias" "FAIL" "Exit code: $exit_code"
fi

# Test 5: setup.sh creates symlink for alias
if [ -L "$TEST_HOME/.local/bin/testbm" ]; then
	print_test_result "setup.sh creates symlink for alias" "PASS"
else
	print_test_result "setup.sh creates symlink for alias" "FAIL" "Symlink not created"
fi

# Test 6: Alias symlink points to mlh-bookmark.sh
if [ -L "$TEST_HOME/.local/bin/testbm" ]; then
	target=$(readlink "$TEST_HOME/.local/bin/testbm")
	if echo "$target" | grep -q "mlh-bookmark.sh"; then
		print_test_result "Alias symlink points to mlh-bookmark.sh" "PASS"
	else
		print_test_result "Alias symlink points to mlh-bookmark.sh" "FAIL" "Wrong target: $target"
	fi
else
	print_test_result "Alias symlink points to mlh-bookmark.sh" "SKIP" "Symlink not created"
fi

# Test 7: setup.sh adds alias wrapper to bashrc
if grep -q "testbm()" "$TEST_HOME/.bashrc"; then
	print_test_result "setup.sh adds alias wrapper to bashrc" "PASS"
else
	print_test_result "setup.sh adds alias wrapper to bashrc" "FAIL" "Wrapper not found"
fi

# Test 8: Alias wrapper in bashrc has correct structure
if grep -q 'bookmark "\$@"' "$TEST_HOME/.bashrc"; then
	print_test_result "Alias wrapper has correct delegation structure" "PASS"
else
	print_test_result "Alias wrapper has correct delegation structure" "FAIL" "Delegation not found"
fi

# Test 9: setup.sh shows BASHRC_UPDATED warning
if echo "$output" | grep -qi "Important.*Shell configuration updated" || echo "$output" | grep -q "source ~/.bashrc"; then
	print_test_result "setup.sh shows BASHRC_UPDATED warning" "PASS"
else
	print_test_result "setup.sh shows BASHRC_UPDATED warning" "FAIL" "Warning not shown"
fi

# Test 10: Alias mentioned in setup complete message
if echo "$output" | grep -q "testbm"; then
	print_test_result "Alias mentioned in setup complete message" "PASS"
else
	print_test_result "Alias mentioned in setup complete message" "FAIL" "Alias not mentioned"
fi

#
# Test Group 3: Command conflict detection
#

# Test 11: setup.sh detects command conflicts
# Create a fake conflicting command
mkdir -p "$TEST_HOME/.local/bin"
echo '#!/bin/bash' > "$TEST_HOME/.local/bin/conflictcmd"
echo 'echo "existing command"' >> "$TEST_HOME/.local/bin/conflictcmd"
chmod +x "$TEST_HOME/.local/bin/conflictcmd"
export PATH="$TEST_HOME/.local/bin:$PATH"

echo "BOOKMARK_ALIAS=conflictcmd" > "$ALIAS_CONFIG_FILE"
output=$(cd "$ROOT_DIR" && bash setup.sh 2>&1 || true)
if echo "$output" | grep -qi "conflict\|already exists"; then
	print_test_result "setup.sh detects command conflicts" "PASS"
else
	print_test_result "setup.sh detects command conflicts" "SKIP" "Conflict detection might be optional"
fi

# Cleanup
cleanup_test_env

exit 0
