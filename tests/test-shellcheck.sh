#!/usr/bin/env bash
# Test suite for ShellCheck validation

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

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

# Test 1: Check if shellcheck is available
if command -v shellcheck >/dev/null 2>&1; then
	print_test_result "ShellCheck availability" "PASS" "Using local shellcheck"
else
	print_test_result "ShellCheck availability" "FAIL" "shellcheck not available. Install with: sudo apt-get install shellcheck"
	exit 1
fi

# Helper function to run shellcheck
run_shellcheck() {
	local file="$1"
	local excludes="${2:-}"

	if [ -n "$excludes" ]; then
		shellcheck --exclude="$excludes" "$file" 2>&1
	else
		shellcheck "$file" 2>&1
	fi
}

# Test 2: Check main scripts (setup.sh, install.sh, get-mlh.sh)
main_scripts=("setup.sh" "install.sh" "get-mlh.sh")
main_errors=0
main_failed=""

for script in "${main_scripts[@]}"; do
	script_path="$ROOT_DIR/$script"
	if [ -f "$script_path" ]; then
		if run_shellcheck "$script_path" >/dev/null 2>&1; then
			print_test_result "ShellCheck: $script" "PASS"
		else
			main_errors=$((main_errors + 1))
			main_failed="$main_failed $script"
			error_msg=$(run_shellcheck "$script_path" 2>&1 | head -2 | tr '\n' ' ')
			print_test_result "ShellCheck: $script" "FAIL" "$error_msg"
		fi
	else
		print_test_result "ShellCheck: $script" "SKIP" "File not found"
	fi
done

# Test 3: Check all plugin scripts
PLUGINS_DIR="$ROOT_DIR/plugins"
plugin_count=0
plugin_errors=0
failed_plugins=""

if [ -d "$PLUGINS_DIR" ]; then
	for plugin in "$PLUGINS_DIR"/*.sh; do
		if [ -f "$plugin" ]; then
			plugin_name=$(basename "$plugin")
			plugin_count=$((plugin_count + 1))

			if run_shellcheck "$plugin" >/dev/null 2>&1; then
				: # PASS - counted below
			else
				plugin_errors=$((plugin_errors + 1))
				failed_plugins="$failed_plugins $plugin_name"
				# Show first error for debugging
				error_msg=$(run_shellcheck "$plugin" 2>&1 | head -3 | tr '\n' ' ')
				if [ -n "$error_msg" ]; then
					echo "  Error in $plugin_name: $error_msg" >&2
				fi
			fi
		fi
	done
fi

if [ "$plugin_errors" -eq 0 ] && [ "$plugin_count" -gt 0 ]; then
	print_test_result "ShellCheck: All plugin scripts ($plugin_count files)" "PASS"
elif [ "$plugin_count" -eq 0 ]; then
	print_test_result "ShellCheck: All plugin scripts" "SKIP" "No plugin scripts found"
else
	print_test_result "ShellCheck: All plugin scripts ($plugin_count files)" "FAIL" "Found issues in $plugin_errors plugin(s):$failed_plugins"
fi

# Test 4: Check test scripts (excluding this file)
TEST_SCRIPTS_DIR="$ROOT_DIR/tests"
test_count=0
test_errors=0
failed_tests=""

# Check root test scripts
for test_script in "$TEST_SCRIPTS_DIR"/*.sh; do
	if [ -f "$test_script" ] && [ "$(basename "$test_script")" != "test-shellcheck.sh" ]; then
		test_name=$(basename "$test_script")
		test_count=$((test_count + 1))

		# Test scripts may have intentional issues, so we use --exclude
		# SC1090: Can't follow non-constant source
		# SC1091: Not following sourced file
		# SC2034: Variable appears unused (may be used in sourced files)
		if run_shellcheck "$test_script" "SC1090,SC1091,SC2034" >/dev/null 2>&1; then
			: # PASS
		else
			test_errors=$((test_errors + 1))
			failed_tests="$failed_tests $test_name"
			# Show first error for debugging
			error_msg=$(run_shellcheck "$test_script" "SC1090,SC1091,SC2034" 2>&1 | head -3 | tr '\n' ' ')
			if [ -n "$error_msg" ]; then
				echo "  Error in $test_name: $error_msg" >&2
			fi
		fi
	fi
done

# Check bookmark test scripts
if [ -d "$TEST_SCRIPTS_DIR/bookmark" ]; then
	for test_script in "$TEST_SCRIPTS_DIR/bookmark"/*.sh; do
		if [ -f "$test_script" ]; then
			test_name=$(basename "$test_script")
			test_count=$((test_count + 1))

			if run_shellcheck "$test_script" "SC1090,SC1091,SC2034" >/dev/null 2>&1; then
				: # PASS
			else
				test_errors=$((test_errors + 1))
				failed_tests="$failed_tests bookmark/$test_name"
				# Show first error for debugging
				error_msg=$(run_shellcheck "$test_script" "SC1090,SC1091,SC2034" 2>&1 | head -3 | tr '\n' ' ')
				if [ -n "$error_msg" ]; then
					echo "  Error in bookmark/$test_name: $error_msg" >&2
				fi
			fi
		fi
	done
fi

if [ "$test_errors" -eq 0 ] && [ "$test_count" -gt 0 ]; then
	print_test_result "ShellCheck: All test scripts ($test_count files)" "PASS"
elif [ "$test_count" -eq 0 ]; then
	print_test_result "ShellCheck: All test scripts" "SKIP" "No test scripts found"
else
	print_test_result "ShellCheck: All test scripts ($test_count files)" "FAIL" "Found issues in $test_errors test script(s):$failed_tests"
fi

exit 0
