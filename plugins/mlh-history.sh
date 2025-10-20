#!/usr/bin/env bash
# mlh-history.sh — Enhanced history command with date formatting and search
#
# Usage:
#   mlh history [options] [count]
#   mlh history --help
#
# Options:
#   -d, --detail            Show detailed history with formatted output
#   -m, --minimal           Show minimal output (commands only)
#   -f, --find <pattern>    Search for commands containing pattern
#   -g, --goto <number>     Show specific command by line number
#   -t, --time <date>       Filter by date (YYYY-MM-DD or YYYY-MM-DD..YYYY-MM-DD)
#   -c, --config            Configure default display mode and date tracking
#   -h, --help              Show this help

set -euo pipefail

# Resolve script directory (handle symlinks)
resolve_script_dir() {
	local source="$0"
	while [ -L "$source" ]; do
		local target
		target="$(readlink "$source")"
		if [[ "$target" = /* ]]; then
			source="$target"
		else
			local dir
			dir="$(cd -P "$(dirname "$source")" && pwd)"
			source="$dir/$target"
		fi
	done
	cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${HOME}/.mylinuxhelper"
HISTORY_CONFIG="${CONFIG_DIR}/.history-config"
BASHRC="${HOME}/.bashrc"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_help() {
	cat <<'EOF'
mlh history - Enhanced history command with dates, search, and filtering

Usage:
  mlh history [options] [count]
  mlh history --help

Options:
  -a, --all               Show all history (override default limit)
  -d, --detail            Show detailed history with formatted output
  -m, --minimal           Show minimal output (commands only)
  -f, --find <pattern>    Search for commands containing pattern
  -g, --goto <number>     Show commands around specific line number (with context)
  -t, --time <time>       Filter by time (formats: YYYY-MM-DD, 3d, 20m, 2h)
  -b, --before <time>     Start time offset (use with -t, formats: 1h, 30m, 2d)
  -c, --config            Configure defaults (display mode, date tracking, limit, context)
  -h, --help              Show this help

Examples:
  mlh history             # Show last 100 commands (default)
  mlh history 10          # Show last 10 commands
  mlh history -a          # Show all history
  mlh history -d          # Show detailed history with formatting
  mlh history -f docker   # Find all commands containing "docker"
  mlh history 10 -f git   # Find last 10 commands containing "git"
  mlh history -g 1432     # Show 5 commands around #1432 (target highlighted in green)
  mlh history 7 -g 1432   # Show 7 commands around #1432 (3 before, target, 3 after)
  mlh history -t 2025-10-20                    # Show commands from specific date
  mlh history -t 2025-10-18..2025-10-20        # Show commands in date range
  mlh history -t 3d       # Show commands from last 3 days
  mlh history -t 20m      # Show commands from last 20 minutes
  mlh history -t 2h       # Show commands from last 2 hours
  mlh history -t 20m -b 1h   # Show 20 minutes of commands starting from 1 hour ago
  mlh history -c          # Configure settings (limit, context, date tracking, display mode)

Display Modes:
  - Simple (default): Shows line numbers, dates (if available), and commands
  - Detailed: Shows formatted output with colors and command info
  - Minimal: Shows only commands without line numbers or dates

Notes:
  - Default shows last 100 commands (configurable)
  - Date tracking requires HISTTIMEFORMAT to be set
  - Configure with 'mlh history -c' to enable date tracking and set default limit
  - Configuration only affects 'mlh history', not the system 'history' command
  - Reads from ~/.bash_history or $HISTFILE
EOF
}

get_config_value() {
	local key="$1"
	if [ -f "${HISTORY_CONFIG}" ]; then
		grep "^${key}=" "${HISTORY_CONFIG}" 2>/dev/null | cut -d'=' -f2 || echo ""
	else
		echo ""
	fi
}

set_config_value() {
	local key="$1"
	local value="$2"
	mkdir -p "${CONFIG_DIR}"

	if [ -f "${HISTORY_CONFIG}" ]; then
		sed -i.bak "/^${key}=/d" "${HISTORY_CONFIG}" 2>/dev/null || true
	fi

	echo "${key}=${value}" >>"${HISTORY_CONFIG}"
}

check_histtimeformat() {
	if [ -z "${HISTTIMEFORMAT:-}" ]; then
		# Check if already configured in bashrc
		if [ -f "$BASHRC" ] && grep -q "^export HISTTIMEFORMAT=" "$BASHRC" 2>/dev/null; then
			# It's in bashrc but not in current session, source it
			local histtime_line
			histtime_line=$(grep "^export HISTTIMEFORMAT=" "$BASHRC" 2>/dev/null | head -1 || echo "")
			if [ -n "$histtime_line" ]; then
				eval "$histtime_line" || true
				return 0
			fi
		fi
		return 1
	fi
	return 0
}

enable_date_tracking() {
	local histtime_export='export HISTTIMEFORMAT='"'"'%F %T  '"'"''

	# Check if already in bashrc
	if grep -q "^export HISTTIMEFORMAT=" "$BASHRC" 2>/dev/null; then
		echo -e "${YELLOW}HISTTIMEFORMAT is already configured in ~/.bashrc${NC}"
		# Source it for current session
		eval "$histtime_export"
		return 0
	fi

	# Add to bashrc
	echo "" >>"$BASHRC"
	echo "# MyLinuxHelper - Enable command history timestamps" >>"$BASHRC"
	echo "$histtime_export" >>"$BASHRC"

	echo -e "${GREEN}✓ Date tracking enabled in ~/.bashrc${NC}"

	# Apply to current session by sourcing bashrc
	eval "$histtime_export"

	echo -e "${GREEN}✓ Applied to current session${NC}"
	echo ""
	echo -e "${CYAN}Note: Future commands will be tracked with dates.${NC}"
	echo -e "${CYAN}Previous commands will not have date information.${NC}"
}

configure_defaults() {
	echo ""
	echo -e "${CYAN}MyLinuxHelper - History Configuration${NC}"
	echo -e "${CYAN}=====================================${NC}"
	echo ""

	# Check if date tracking is enabled
	local date_enabled=false
	if check_histtimeformat; then
		date_enabled=true
		echo -e "${GREEN}✓ Date tracking: Enabled${NC}"
	else
		echo -e "${YELLOW}⚠ Date tracking: Disabled${NC}"
	fi
	echo ""

	# Ask about date tracking if not enabled
	if [ "$date_enabled" = false ]; then
		echo "Would you like to enable date tracking for command history?"
		echo ""
		echo "1. Enable date tracking (Recommended) - Track dates for future commands"
		echo "2. Keep disabled - Commands without dates"
		echo ""
		read -rp "Select [1-2]: " DATE_SELECTION
		echo ""

		case "$DATE_SELECTION" in
		1)
			enable_date_tracking
			;;
		2)
			echo "Date tracking remains disabled."
			;;
		*)
			echo "Invalid selection. No changes made."
			;;
		esac
		echo ""
	fi

	# Display mode configuration
	echo "Choose default display mode for 'mlh history':"
	echo ""
	echo "1. Simple (numbered with dates) - Recommended"
	echo "2. Detailed - Formatted output with colors"
	echo "3. Minimal - Commands only"
	echo ""

	local current_mode
	current_mode="$(get_config_value "DEFAULT_MODE")"

	if [ -n "$current_mode" ]; then
		case "$current_mode" in
		simple) echo "Current setting: Simple" ;;
		detailed) echo "Current setting: Detailed" ;;
		minimal) echo "Current setting: Minimal" ;;
		esac
		echo ""
	fi

	read -rp "Select [1-3]: " MODE_SELECTION
	echo ""

	case "$MODE_SELECTION" in
	1)
		set_config_value "DEFAULT_MODE" "simple"
		echo "✓ Default mode set to: Simple"
		;;
	2)
		set_config_value "DEFAULT_MODE" "detailed"
		echo "✓ Default mode set to: Detailed"
		;;
	3)
		set_config_value "DEFAULT_MODE" "minimal"
		echo "✓ Default mode set to: Minimal"
		;;
	*)
		echo "Invalid selection. No changes made."
		;;
	esac

	echo ""

	# Default count configuration
	echo "Choose default number of commands to show:"
	echo ""
	local current_limit
	current_limit="$(get_config_value "DEFAULT_LIMIT")"
	if [ -n "$current_limit" ]; then
		echo "Current setting: $current_limit commands"
	else
		echo "Current setting: 100 commands (default)"
	fi
	echo ""
	read -rp "Enter number of commands (leave empty for 100): " LIMIT_INPUT
	echo ""

	if [ -n "$LIMIT_INPUT" ]; then
		if [[ "$LIMIT_INPUT" =~ ^[0-9]+$ ]]; then
			set_config_value "DEFAULT_LIMIT" "$LIMIT_INPUT"
			echo "✓ Default limit set to: $LIMIT_INPUT commands"
		else
			echo "Invalid input. Must be a number."
		fi
	else
		set_config_value "DEFAULT_LIMIT" "100"
		echo "✓ Default limit set to: 100 commands"
	fi

	echo ""

	# Default context size configuration for -g flag
	echo "Choose default context size for 'mlh history -g' (commands around target):"
	echo ""
	local current_context
	current_context="$(get_config_value "DEFAULT_CONTEXT")"
	if [ -n "$current_context" ]; then
		echo "Current setting: $current_context commands"
	else
		echo "Current setting: 5 commands (default)"
	fi
	echo ""
	read -rp "Enter context size (leave empty for 5): " CONTEXT_INPUT
	echo ""

	if [ -n "$CONTEXT_INPUT" ]; then
		if [[ "$CONTEXT_INPUT" =~ ^[0-9]+$ ]]; then
			set_config_value "DEFAULT_CONTEXT" "$CONTEXT_INPUT"
			echo "✓ Default context size set to: $CONTEXT_INPUT commands"
		else
			echo "Invalid input. Must be a number."
		fi
	else
		set_config_value "DEFAULT_CONTEXT" "5"
		echo "✓ Default context size set to: 5 commands"
	fi

	echo ""
	echo "Configuration saved to: ${HISTORY_CONFIG}"
}

# Parse history file with timestamps
parse_history_with_timestamps() {
	local histfile="${HISTFILE:-$HOME/.bash_history}"

	# Note: The mlh wrapper function in ~/.bashrc calls 'history -a' before
	# invoking this script, so the history file should already contain
	# the current session's commands

	if [ ! -f "$histfile" ]; then
		return 1
	fi

	local line_num=0
	local timestamp=""

	while IFS= read -r line || [ -n "$line" ]; do
		if [[ "$line" =~ ^#([0-9]+)$ ]]; then
			# This is a timestamp
			timestamp="${BASH_REMATCH[1]}"
		else
			# This is a command
			line_num=$((line_num + 1))
			if [ -n "$timestamp" ]; then
				# Format: line_num|timestamp|command
				echo "${line_num}|${timestamp}|${line}"
				timestamp=""
			else
				# No timestamp available
				echo "${line_num}||${line}"
			fi
		fi
	done <"$histfile"

	return 0
}

# Convert timestamp to readable date
timestamp_to_date() {
	local ts="$1"
	if [ -n "$ts" ]; then
		date -d "@${ts}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "${ts}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo ""
	fi
}

# Parse relative time (e.g., 3d, 20m, 2h) and return seconds
parse_relative_time() {
	local time_str="$1"

	if [[ "$time_str" =~ ^([0-9]+)([dhm])$ ]]; then
		local value="${BASH_REMATCH[1]}"
		local unit="${BASH_REMATCH[2]}"

		case "$unit" in
		d) # days
			echo $((value * 86400))
			;;
		h) # hours
			echo $((value * 3600))
			;;
		m) # minutes
			echo $((value * 60))
			;;
		*)
			echo ""
			return 1
			;;
		esac
	else
		echo ""
		return 1
	fi
}

show_history_simple() {
	local count="${1:-}"
	local has_dates=false

	check_histtimeformat && has_dates=true

	if [ "$has_dates" = false ]; then
		echo -e "${YELLOW}Note: Dates not available. Run 'mlh history -c' to enable date tracking.${NC}"
		echo ""
	fi

	# Create temp file for history data
	local temp_file=$(mktemp)
	parse_history_with_timestamps >"$temp_file" || {
		echo -e "${RED}Error: Failed to parse history${NC}"
		rm -f "$temp_file"
		return 1
	}

	# Check if temp file has content
	if [ ! -s "$temp_file" ]; then
		echo -e "${RED}Error: No history data found${NC}"
		rm -f "$temp_file"
		return 1
	fi

	# Create a second temp file for filtered output if needed
	local display_file="$temp_file"
	if [ -n "$count" ]; then
		display_file=$(mktemp)
		tail -n "$count" "$temp_file" >"$display_file"
	fi

	# Read and display
	while IFS='|' read -r num ts cmd; do
		if [ -n "$ts" ] && [ "$has_dates" = true ]; then
			local date=$(timestamp_to_date "$ts")
			printf "%-6s  %-19s  %s\n" "$num" "$date" "$cmd"
		else
			printf "%-6s  %s\n" "$num" "$cmd"
		fi
	done <"$display_file"

	# Cleanup
	rm -f "$temp_file"
	if [ "$display_file" != "$temp_file" ]; then
		rm -f "$display_file"
	fi
}

show_history_detailed() {
	local count="${1:-}"
	local has_dates=false

	check_histtimeformat && has_dates=true

	echo -e "${CYAN}Detailed History${NC}"
	echo -e "${CYAN}=================${NC}"
	echo ""

	if [ "$has_dates" = false ]; then
		echo -e "${YELLOW}Note: Dates not available. Run 'mlh history -c' to enable date tracking.${NC}"
		echo ""
	fi

	# Create temp file for history data
	local temp_file=$(mktemp)
	parse_history_with_timestamps >"$temp_file" || {
		echo -e "${RED}Error: Failed to parse history${NC}"
		rm -f "$temp_file"
		return 1
	}

	# Check if temp file has content
	if [ ! -s "$temp_file" ]; then
		echo -e "${RED}Error: No history data found${NC}"
		rm -f "$temp_file"
		return 1
	fi

	# Create a second temp file for filtered output if needed
	local display_file="$temp_file"
	if [ -n "$count" ]; then
		display_file=$(mktemp)
		tail -n "$count" "$temp_file" >"$display_file"
	fi

	# Read and display
	while IFS='|' read -r num ts cmd; do
		echo -e "${YELLOW}#${num}${NC}"
		if [ -n "$ts" ] && [ "$has_dates" = true ]; then
			local date=$(timestamp_to_date "$ts")
			echo -e "  ${GREEN}Date:${NC} $date"
		fi
		echo -e "  ${BLUE}Command:${NC} $cmd"
		echo ""
	done <"$display_file"

	# Cleanup
	rm -f "$temp_file"
	if [ "$display_file" != "$temp_file" ]; then
		rm -f "$display_file"
	fi
}

show_history_minimal() {
	local count="${1:-}"
	local histfile="${HISTFILE:-$HOME/.bash_history}"

	if [ ! -f "$histfile" ]; then
		echo "No history file found at: $histfile"
		return 1
	fi

	# Skip timestamp lines (starting with #) and show only commands
	if [ -n "$count" ]; then
		grep -v '^#' "$histfile" | tail -n "$count"
	else
		grep -v '^#' "$histfile"
	fi
}

find_in_history() {
	local pattern="$1"
	local limit="${2:-}"
	local has_dates=false

	check_histtimeformat && has_dates=true

	if [ -n "$limit" ]; then
		echo -e "${CYAN}Searching for last ${YELLOW}${limit}${CYAN} commands matching: ${YELLOW}${pattern}${NC}"
	else
		echo -e "${CYAN}Searching for: ${YELLOW}${pattern}${NC}"
	fi
	echo ""

	local temp_file=$(mktemp)
	parse_history_with_timestamps >"$temp_file" || {
		echo -e "${RED}Error: Failed to parse history${NC}"
		rm -f "$temp_file"
		return 1
	}

	# First pass: collect matching commands
	local matches_file=$(mktemp)
	while IFS='|' read -r num ts cmd; do
		if [[ "$cmd" == *"$pattern"* ]]; then
			echo "${num}|${ts}|${cmd}" >>"$matches_file"
		fi
	done <"$temp_file"

	rm -f "$temp_file"

	# Count total matches
	local total_matches=0
	if [ -f "$matches_file" ] && [ -s "$matches_file" ]; then
		total_matches=$(wc -l <"$matches_file" | tr -d ' ')
	fi

	if [ "$total_matches" -eq 0 ]; then
		echo -e "${YELLOW}No commands found matching '${pattern}'${NC}"
		rm -f "$matches_file"
		return 0
	fi

	# Second pass: display last N matches
	local display_file="$matches_file"
	if [ -n "$limit" ]; then
		display_file=$(mktemp)
		tail -n "$limit" "$matches_file" >"$display_file"
	fi

	local shown=0
	while IFS='|' read -r num ts cmd; do
		shown=$((shown + 1))
		if [ -n "$ts" ] && [ "$has_dates" = true ]; then
			local date=$(timestamp_to_date "$ts")
			echo -e "${GREEN}#${num}${NC} ${YELLOW}[${date}]${NC}"
		else
			echo -e "${GREEN}#${num}${NC}"
		fi
		echo -e "  ${cmd}"
		echo ""
	done <"$display_file"

	# Cleanup
	rm -f "$matches_file"
	if [ "$display_file" != "$matches_file" ]; then
		rm -f "$display_file"
	fi

	# Show summary
	if [ -n "$limit" ] && [ "$total_matches" -gt "$shown" ]; then
		echo -e "${GREEN}Showing last ${shown} of ${total_matches} matching command(s)${NC}"
	else
		echo -e "${GREEN}Found ${shown} matching command(s)${NC}"
	fi
}

goto_command() {
	local target_num="$1"
	local context="${2:-}"
	local has_dates=false

	check_histtimeformat && has_dates=true

	# Get default context size from config if not provided
	if [ -z "$context" ]; then
		context="$(get_config_value "DEFAULT_CONTEXT" || echo "")"
		if [ -z "$context" ] || [ "$context" = "" ]; then
			context="5"
		fi
	fi

	# Calculate range: show (context-1)/2 commands before and after target
	local half_context=$(((context - 1) / 2))
	local start_num=$((target_num - half_context))
	local end_num=$((target_num + half_context))

	# Ensure start_num is at least 1
	if [ "$start_num" -lt 1 ]; then
		start_num=1
		end_num=$((start_num + context - 1))
	fi

	local temp_file=$(mktemp)
	parse_history_with_timestamps >"$temp_file" || {
		echo -e "${RED}Error: Failed to parse history${NC}"
		rm -f "$temp_file"
		return 1
	}

	echo -e "${CYAN}Showing ${context} commands around #${target_num}${NC}"
	echo ""

	local found=false
	local shown=0
	while IFS='|' read -r num ts cmd; do
		if [ "$num" -ge "$start_num" ] && [ "$num" -le "$end_num" ] && [ "$shown" -lt "$context" ]; then
			shown=$((shown + 1))

			# Highlight the target command in green
			if [ "$num" = "$target_num" ]; then
				found=true
				if [ -n "$ts" ] && [ "$has_dates" = true ]; then
					local date=$(timestamp_to_date "$ts")
					echo -e "${GREEN}► ${num}${NC}  ${YELLOW}${date}${NC}  ${GREEN}${cmd}${NC}"
				else
					echo -e "${GREEN}► ${num}${NC}  ${GREEN}${cmd}${NC}"
				fi
			else
				if [ -n "$ts" ] && [ "$has_dates" = true ]; then
					local date=$(timestamp_to_date "$ts")
					printf "  %-6s  %-19s  %s\n" "$num" "$date" "$cmd"
				else
					printf "  %-6s  %s\n" "$num" "$cmd"
				fi
			fi
		fi
	done <"$temp_file"

	rm -f "$temp_file"

	if [ "$found" = false ]; then
		echo -e "${RED}Command #${target_num} not found${NC}"
		return 1
	fi
}

filter_by_date() {
	local date_filter="$1"
	local before_offset="${2:-}"
	local has_dates=false

	check_histtimeformat && has_dates=true

	if [ "$has_dates" = false ]; then
		echo -e "${RED}Error: Date tracking is not enabled.${NC}"
		echo -e "${YELLOW}Run 'mlh history -c' to enable date tracking.${NC}"
		return 1
	fi

	local start_ts=""
	local end_ts=""
	local current_ts
	current_ts=$(date +%s)

	# Check if it's a relative time format (e.g., 3d, 20m, 2h)
	local relative_seconds
	relative_seconds=$(parse_relative_time "$date_filter")

	if [ -n "$relative_seconds" ]; then
		# Relative time format
		local before_seconds=0

		# If before offset is provided, parse it
		if [ -n "$before_offset" ]; then
			before_seconds=$(parse_relative_time "$before_offset")
			if [ -z "$before_seconds" ]; then
				echo -e "${RED}Error: Invalid before offset format. Use formats like: 1h, 30m, 2d${NC}"
				return 1
			fi
		fi

		# Calculate time range
		# End time is: current time - before_offset
		end_ts=$((current_ts - before_seconds))
		# Start time is: end_time - duration
		start_ts=$((end_ts - relative_seconds))

		# Format for display
		local start_display=$(timestamp_to_date "$start_ts")
		local end_display=$(timestamp_to_date "$end_ts")

		if [ -n "$before_offset" ]; then
			echo -e "${CYAN}Commands: ${YELLOW}${date_filter}${CYAN} starting from ${YELLOW}${before_offset}${CYAN} ago${NC}"
		else
			echo -e "${CYAN}Commands from last ${YELLOW}${date_filter}${NC}"
		fi
		echo -e "${CYAN}Time range: ${YELLOW}${start_display}${CYAN} to ${YELLOW}${end_display}${NC}"
		echo ""

	else
		# Absolute date format (YYYY-MM-DD or range)
		local start_date=""
		local end_date=""

		if [[ "$date_filter" == *".."* ]]; then
			# Date range: YYYY-MM-DD..YYYY-MM-DD
			start_date="${date_filter%%..*}"
			end_date="${date_filter##*..}"
		else
			# Single date
			start_date="$date_filter"
			end_date="$date_filter"
		fi

		# Convert dates to timestamps
		start_ts=$(date -d "$start_date 00:00:00" +%s 2>/dev/null)
		end_ts=$(date -d "$end_date 23:59:59" +%s 2>/dev/null)

		if [ -z "$start_ts" ] || [ -z "$end_ts" ]; then
			echo -e "${RED}Error: Invalid date format. Use YYYY-MM-DD, YYYY-MM-DD..YYYY-MM-DD, or relative time (3d, 20m, 2h)${NC}"
			return 1
		fi

		echo -e "${CYAN}Commands from ${YELLOW}${start_date}${CYAN} to ${YELLOW}${end_date}${NC}"
		echo ""
	fi

	# Parse and filter history
	local temp_file=$(mktemp)
	parse_history_with_timestamps >"$temp_file" || {
		echo -e "${RED}Error: Failed to parse history${NC}"
		rm -f "$temp_file"
		return 1
	}

	local found=0
	local total_with_ts=0
	local newest_ts=0
	local oldest_ts=9999999999

	while IFS='|' read -r num ts cmd; do
		if [ -n "$ts" ]; then
			total_with_ts=$((total_with_ts + 1))

			# Track newest and oldest timestamps
			if [ "$ts" -gt "$newest_ts" ]; then
				newest_ts="$ts"
			fi
			if [ "$ts" -lt "$oldest_ts" ]; then
				oldest_ts="$ts"
			fi

			if [ "$ts" -ge "$start_ts" ] && [ "$ts" -le "$end_ts" ]; then
				found=$((found + 1))
				local date=$(timestamp_to_date "$ts")
				echo -e "${GREEN}#${num}${NC} ${YELLOW}[${date}]${NC}"
				echo -e "  ${cmd}"
				echo ""
			fi
		fi
	done <"$temp_file"

	rm -f "$temp_file"

	if [ "$found" -eq 0 ]; then
		echo -e "${YELLOW}No commands found in the specified time range${NC}"

		# Provide helpful debugging information
		if [ "$total_with_ts" -gt 0 ] && [ "$newest_ts" -gt 0 ]; then
			local newest_date=$(timestamp_to_date "$newest_ts")
			local time_diff=$((current_ts - newest_ts))
			local time_diff_mins=$((time_diff / 60))
			local time_diff_hours=$((time_diff / 3600))
			local time_diff_days=$((time_diff / 86400))

			echo ""
			echo -e "${CYAN}Latest command in history:${NC} $newest_date"

			if [ "$time_diff" -lt 3600 ]; then
				echo -e "${CYAN}That was${NC} ${YELLOW}${time_diff_mins} minutes ago${NC}"
			elif [ "$time_diff" -lt 86400 ]; then
				echo -e "${CYAN}That was${NC} ${YELLOW}${time_diff_hours} hours ago${NC}"
			else
				echo -e "${CYAN}That was${NC} ${YELLOW}${time_diff_days} days ago${NC}"
			fi

			echo ""
			echo -e "${CYAN}Tip:${NC} Try a larger time range (e.g., ${YELLOW}mlh history -t ${time_diff_hours}h${NC})"
		fi
	else
		echo -e "${GREEN}Found ${found} command(s)${NC}"
	fi
}

main() {
	local mode=""
	local count=""
	local default_mode
	local default_limit
	local find_pattern=""
	local goto_num=""
	local date_filter=""
	local before_offset=""
	local show_all=false

	# Get default mode from config (default to "simple")
	default_mode="$(get_config_value "DEFAULT_MODE")"
	if [ -z "$default_mode" ]; then
		default_mode="simple"
	fi

	# Get default limit from config (default to 100)
	default_limit="$(get_config_value "DEFAULT_LIMIT" || echo "")"
	if [ -z "$default_limit" ] || [ "$default_limit" = "" ]; then
		default_limit="100"
	fi

	# Parse arguments
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			print_help
			exit 0
			;;
		-a | --all)
			show_all=true
			shift
			;;
		-d | --detail)
			mode="detailed"
			shift
			;;
		-c | --config)
			configure_defaults
			exit 0
			;;
		-m | --minimal)
			mode="minimal"
			shift
			;;
		-f | --find)
			shift
			if [ $# -eq 0 ]; then
				echo -e "${RED}Error: --find requires a pattern${NC}"
				exit 1
			fi
			find_pattern="$1"
			shift
			;;
		-g | --goto)
			shift
			if [ $# -eq 0 ]; then
				echo -e "${RED}Error: --goto requires a line number${NC}"
				exit 1
			fi
			goto_num="$1"
			shift
			;;
		-t | --time)
			shift
			if [ $# -eq 0 ]; then
				echo -e "${RED}Error: --time requires a date or date range${NC}"
				exit 1
			fi
			date_filter="$1"
			shift
			;;
		-b | --before)
			shift
			if [ $# -eq 0 ]; then
				echo -e "${RED}Error: --before requires a time offset${NC}"
				exit 1
			fi
			before_offset="$1"
			shift
			;;
		-*)
			echo "Error: Unknown option '$1'" >&2
			echo "Run 'mlh history --help' for usage information." >&2
			exit 1
			;;
		*)
			# Assume it's a count
			if [[ "$1" =~ ^[0-9]+$ ]]; then
				count="$1"
			else
				echo "Error: Invalid argument '$1'" >&2
				echo "Run 'mlh history --help' for usage information." >&2
				exit 1
			fi
			shift
			;;
		esac
	done

	# Handle special operations
	if [ -n "$find_pattern" ]; then
		# If count is provided with -f, use it as limit
		find_in_history "$find_pattern" "$count"
		exit 0
	fi

	if [ -n "$goto_num" ]; then
		# If count is provided with -g, use it as context size
		goto_command "$goto_num" "$count"
		exit 0
	fi

	if [ -n "$date_filter" ]; then
		filter_by_date "$date_filter" "$before_offset"
		exit 0
	fi

	# Check if before_offset was provided without date_filter
	if [ -n "$before_offset" ]; then
		echo -e "${RED}Error: --before requires --time to be specified${NC}"
		exit 1
	fi

	# Use explicit mode if provided, otherwise use default
	if [ -z "$mode" ]; then
		mode="$default_mode"
	fi

	# Apply default limit if no count specified and not showing all
	if [ -z "$count" ]; then
		if [ "$show_all" != "true" ]; then
			count="$default_limit"
		fi
	fi

	# If showing all, clear count
	if [ "$show_all" = "true" ]; then
		count=""
	fi

	# Display history based on mode
	case "$mode" in
	simple)
		show_history_simple "$count"
		;;
	detailed)
		show_history_detailed "$count"
		;;
	minimal)
		show_history_minimal "$count"
		;;
	*)
		echo "Error: Unknown mode '$mode'" >&2
		exit 1
		;;
	esac
}

main "$@"
