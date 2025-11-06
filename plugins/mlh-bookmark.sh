#!/usr/bin/env bash
# mlh-bookmark.sh - Quick directory bookmark system for fast navigation
#
# Usage:
#   bookmark .                    # Save current directory (numbered)
#   bookmark 1                    # Jump to bookmark 1
#   bookmark . -n myproject       # Save with name
#   bookmark myproject            # Jump to named bookmark
#   bookmark 1 -n myapp          # Rename bookmark 1 to myapp
#   bookmark list                 # List all bookmarks
#   bookmark list 5               # List last 5 unnamed bookmarks
#   bookmark --help               # Show help

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m' # No Color

# Configuration
readonly VERSION="1.0.0"
readonly MLH_CONFIG_DIR="${HOME}/.mylinuxhelper"
readonly BOOKMARK_FILE="${MLH_BOOKMARK_FILE:-$MLH_CONFIG_DIR/bookmarks.json}"
readonly MAX_UNNAMED_BOOKMARKS=10

# Common command names to block as bookmark names
readonly BLOCKED_NAMES=(
	"ls" "cd" "pwd" "rm" "mv" "cp" "cat" "less" "more" "grep" "find" "sed" "awk"
	"echo" "mkdir" "rmdir" "touch" "chmod" "chown" "ln" "tar" "gzip" "zip"
	"git" "docker" "npm" "yarn" "python" "node" "java" "make" "ssh" "scp"
	"mlh" "bookmark" "list" "help" "clear" "exit" "source" "export"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if jq is installed
check_jq() {
	if ! command -v jq >/dev/null 2>&1; then
		echo -e "${RED}Error: jq is required for bookmark functionality${NC}" >&2
		echo -e "${YELLOW}Install with: sudo apt install jq${NC}" >&2
		echo -e "${YELLOW}Or run: mlh install jq${NC}" >&2
		exit 1
	fi
}

# Initialize bookmark file with default structure
init_bookmark_file() {
	mkdir -p "$(dirname "$BOOKMARK_FILE")"

	cat >"$BOOKMARK_FILE" <<'EOF'
{
  "version": "1.0",
  "bookmarks": {
    "named": [],
    "unnamed": []
  },
  "config": {
    "max_unnamed": 10,
    "auto_cleanup": true
  }
}
EOF
}

# Get current timestamp in ISO 8601 format
get_timestamp() {
	date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S%z"
}

# Validate bookmark name
validate_name() {
	local name="$1"

	# Check if empty
	if [ -z "$name" ]; then
		echo -e "${RED}Error: Bookmark name cannot be empty${NC}" >&2
		return 1
	fi

	# Check if it's a blocked command name
	for blocked in "${BLOCKED_NAMES[@]}"; do
		if [ "$name" = "$blocked" ]; then
			echo -e "${RED}Error: Invalid name '$name'${NC}" >&2
			echo -e "${YELLOW}This name conflicts with an existing command.${NC}" >&2
			echo -e "${YELLOW}Conflicting command: $(command -v "$name" 2>/dev/null || echo "built-in")${NC}" >&2
			return 1
		fi
	done

	# Check if command exists with this name
	if command -v "$name" >/dev/null 2>&1; then
		echo -e "${RED}Error: Invalid name '$name'${NC}" >&2
		echo -e "${YELLOW}This name conflicts with an existing command: $(command -v "$name")${NC}" >&2
		return 1
	fi

	return 0
}

# Check if named bookmark exists
bookmark_exists() {
	local name="$1"
	[ ! -f "$BOOKMARK_FILE" ] && return 1
	local count
	count=$(jq --arg name "$name" '[.bookmarks.named[] | select(.name == $name)] | length' "$BOOKMARK_FILE" 2>/dev/null)
	[ "${count:-0}" -gt 0 ]
}

# Check if path exists
path_exists() {
	local path="$1"
	[ -d "$path" ]
}

# ============================================================================
# CORE BOOKMARK FUNCTIONS
# ============================================================================

# Save current directory as unnamed bookmark
save_unnamed_bookmark() {
	local path="$1"
	local timestamp
	timestamp=$(get_timestamp)

	# Create bookmark file if it doesn't exist
	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	# Add to unnamed bookmarks (push to front)
	local temp_file
	temp_file=$(mktemp)

	jq --arg path "$path" \
		--arg created "$timestamp" \
		--argjson max "$MAX_UNNAMED_BOOKMARKS" \
		'.bookmarks.unnamed = [{path: $path, created: $created}] + .bookmarks.unnamed |
         .bookmarks.unnamed = .bookmarks.unnamed[0:$max] |
         .bookmarks.unnamed = [.bookmarks.unnamed | to_entries[] | {id: (.key + 1), path: .value.path, created: .value.created}]' \
		"$BOOKMARK_FILE" >"$temp_file"

	mv "$temp_file" "$BOOKMARK_FILE"

	echo -e "${GREEN}✓ Saved as bookmark 1:${NC} $path"
}

# Save named bookmark
save_named_bookmark() {
	local name="$1"
	local path="$2"
	local category="${3:-}"
	local timestamp
	timestamp=$(get_timestamp)

	# Validate name
	validate_name "$name" || return 1

	# Check for duplicates
	if bookmark_exists "$name"; then
		echo -e "${RED}Error: Bookmark '$name' already exists${NC}" >&2
		local existing_path
		existing_path=$(jq -r --arg name "$name" '.bookmarks.named[] | select(.name == $name) | .path' "$BOOKMARK_FILE")
		echo -e "${YELLOW}Existing path: $existing_path${NC}" >&2
		return 1
	fi

	# Create bookmark file if it doesn't exist
	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	# Add named bookmark
	local temp_file
	temp_file=$(mktemp)

	if [ -n "$category" ]; then
		jq --arg name "$name" \
			--arg path "$path" \
			--arg category "$category" \
			--arg created "$timestamp" \
			'.bookmarks.named += [{name: $name, path: $path, category: $category, created: $created, accessed: $created, access_count: 0}]' \
			"$BOOKMARK_FILE" >"$temp_file"
	else
		jq --arg name "$name" \
			--arg path "$path" \
			--arg created "$timestamp" \
			'.bookmarks.named += [{name: $name, path: $path, created: $created, accessed: $created, access_count: 0}]' \
			"$BOOKMARK_FILE" >"$temp_file"
	fi

	mv "$temp_file" "$BOOKMARK_FILE"

	echo -e "${GREEN}✓ Saved bookmark:${NC} $name ${GRAY}→${NC} $path"
	[ -n "$category" ] && echo -e "${CYAN}  Category:${NC} $category"
}

# Rename unnamed bookmark to named
rename_bookmark() {
	local bookmark_id="$1"
	local new_name="$2"
	local category="${3:-}"

	# Validate name
	validate_name "$new_name" || return 1

	# Check for duplicates
	if bookmark_exists "$new_name"; then
		echo -e "${RED}Error: Bookmark '$new_name' already exists${NC}" >&2
		return 1
	fi

	# Get path from unnamed bookmark
	local path
	path=$(jq -r --argjson id "$bookmark_id" '.bookmarks.unnamed[] | select(.id == $id) | .path' "$BOOKMARK_FILE" 2>/dev/null)

	if [ -z "$path" ] || [ "$path" = "null" ]; then
		echo -e "${RED}Error: Bookmark $bookmark_id not found${NC}" >&2
		return 1
	fi

	# Remove from unnamed
	local temp_file
	temp_file=$(mktemp)
	jq --argjson id "$bookmark_id" '.bookmarks.unnamed = [.bookmarks.unnamed[] | select(.id != $id)]' "$BOOKMARK_FILE" >"$temp_file"
	mv "$temp_file" "$BOOKMARK_FILE"

	# Add as named bookmark
	save_named_bookmark "$new_name" "$path" "$category"
}

# Jump to bookmark
jump_to_bookmark() {
	local target="$1"
	local path=""

	# Check if target is a number (unnamed bookmark)
	if [[ "$target" =~ ^[0-9]+$ ]]; then
		path=$(jq -r --argjson id "$target" '.bookmarks.unnamed[] | select(.id == $id) | .path' "$BOOKMARK_FILE" 2>/dev/null)
	else
		# Named bookmark
		path=$(jq -r --arg name "$target" '.bookmarks.named[] | select(.name == $name) | .path' "$BOOKMARK_FILE" 2>/dev/null)

		# Update access count and timestamp
		if [ -n "$path" ] && [ "$path" != "null" ]; then
			local temp_file
			temp_file=$(mktemp)
			local timestamp
			timestamp=$(get_timestamp)
			jq --arg name "$target" \
				--arg timestamp "$timestamp" \
				'(.bookmarks.named[] | select(.name == $name) | .accessed) = $timestamp |
                 (.bookmarks.named[] | select(.name == $name) | .access_count) += 1' \
				"$BOOKMARK_FILE" >"$temp_file"
			mv "$temp_file" "$BOOKMARK_FILE"
		fi
	fi

	# Check if bookmark found
	if [ -z "$path" ] || [ "$path" = "null" ]; then
		echo -e "${RED}Error: Bookmark '$target' not found${NC}" >&2
		return 1
	fi

	# Check if path still exists
	if ! path_exists "$path"; then
		echo -e "${YELLOW}Warning: Bookmark path no longer exists${NC}" >&2
		echo -e "${YELLOW}Path: $path (deleted on disk)${NC}" >&2
		return 1
	fi

	# Output cd command for sourcing
	echo "cd \"$path\""
	echo -e "${GREEN}→${NC} $path" >&2
}

# List all bookmarks
list_bookmarks() {
	local limit="${1:-}"

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${CYAN}📚 Bookmarks${NC}"
	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo ""

	# Named bookmarks
	local named_count
	named_count=$(jq '.bookmarks.named | length' "$BOOKMARK_FILE" 2>/dev/null)

	if [ "$named_count" -gt 0 ]; then
		echo -e "${BLUE}📂 Named Bookmarks${NC}"
		jq -r '.bookmarks.named[] |
               "  [\(.name)]  \(.path)  \(.created | split("T")[0])"' \
			"$BOOKMARK_FILE" 2>/dev/null | while IFS= read -r line; do
			# Check if path exists and add warning symbol
			local path
			path=$(echo "$line" | awk '{print $2}')
			if [ -d "$path" ]; then
				echo -e "$line"
			else
				echo -e "$line ${YELLOW}⚠${NC}"
			fi
		done
		echo ""
	fi

	# Unnamed bookmarks
	local unnamed_count
	unnamed_count=$(jq '.bookmarks.unnamed | length' "$BOOKMARK_FILE" 2>/dev/null)

	if [ "$unnamed_count" -gt 0 ]; then
		echo -e "${BLUE}📌 Recent (Unnamed)${NC}"

		local query='.bookmarks.unnamed[]'
		if [ -n "$limit" ] && [[ "$limit" =~ ^[0-9]+$ ]]; then
			query=".bookmarks.unnamed[0:$limit][]"
		fi

		jq -r "$query |
               \"  \(.id): \(.path)  \(.created | split(\"T\")[0])\"" \
			"$BOOKMARK_FILE" 2>/dev/null | while IFS= read -r line; do
			# Check if path exists
			local path
			path=$(echo "$line" | awk '{print $2}')
			if [ -d "$path" ]; then
				echo -e "$line"
			else
				echo -e "$line ${YELLOW}⚠${NC}"
			fi
		done
		echo ""
	fi

	if [ "$named_count" -eq 0 ] && [ "$unnamed_count" -eq 0 ]; then
		echo -e "${GRAY}  No bookmarks yet. Use 'bookmark .' to save current directory.${NC}"
		echo ""
	fi

	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show help
show_help() {
	cat <<EOF
${CYAN}mlh-bookmark.sh${NC} - Quick directory bookmark system (v$VERSION)

${YELLOW}USAGE:${NC}
  bookmark .                    Save current directory as numbered bookmark
  bookmark 1                    Jump to bookmark 1
  bookmark . -n <name>          Save current directory with name
  bookmark <name>               Jump to named bookmark
  bookmark 1 -n <name>          Rename bookmark 1 to name
  bookmark list                 List all bookmarks
  bookmark list <N>             List last N unnamed bookmarks
  bookmark --help               Show this help

${YELLOW}EXAMPLES:${NC}
  ${GREEN}# Quick numbered bookmarks${NC}
  bookmark .                    # Save current dir (becomes bookmark 1)
  cd /some/other/path
  bookmark .                    # Save another dir (becomes bookmark 1, previous becomes 2)
  bookmark 1                    # Jump to most recent bookmark
  bookmark 2                    # Jump to second most recent

  ${GREEN}# Named bookmarks${NC}
  bookmark . -n myproject       # Save current dir as 'myproject'
  bookmark myproject            # Jump to myproject
  bookmark 1 -n webapp          # Rename bookmark 1 to 'webapp'

  ${GREEN}# List bookmarks${NC}
  bookmark list                 # Show all bookmarks
  bookmark list 5               # Show last 5 unnamed bookmarks

${YELLOW}FEATURES:${NC}
  • Stack-based numbered bookmarks (max 10)
  • Named bookmarks for important locations
  • Path validation and warnings
  • Command name conflict detection
  • JSON storage at: $BOOKMARK_FILE

${YELLOW}SYMBOLS:${NC}
  ⚠  Path no longer exists on disk
  →  Navigating to bookmark
  ✓  Bookmark saved successfully

EOF
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

main() {
	# Parse arguments
	if [ $# -eq 0 ]; then
		show_help
		exit 0
	fi

	case "$1" in
	--help | -h)
		show_help
		exit 0
		;;
	--version | -v)
		echo "mlh-bookmark.sh v$VERSION"
		exit 0
		;;
	list)
		# Check dependencies for actual operations
		check_jq
		shift
		list_bookmarks "$@"
		exit 0
		;;
	.)
		# Check dependencies
		check_jq

		# Save current directory
		local current_dir
		current_dir=$(pwd)

		# Check for -n flag (name)
		if [ $# -ge 3 ] && [ "$2" = "-n" ]; then
			local name="$3"
			local category=""

			# Check for category (in <category>)
			if [ $# -ge 5 ] && [ "$4" = "in" ]; then
				category="$5"
			fi

			save_named_bookmark "$name" "$current_dir" "$category"
		else
			save_unnamed_bookmark "$current_dir"
		fi
		;;
	[0-9]*)
		# Check dependencies
		check_jq

		# Jump to numbered bookmark OR rename it
		local bookmark_id="$1"

		if [ $# -ge 3 ] && [ "$2" = "-n" ]; then
			# Rename bookmark
			local name="$3"
			local category=""

			if [ $# -ge 5 ] && [ "$4" = "in" ]; then
				category="$5"
			fi

			rename_bookmark "$bookmark_id" "$name" "$category"
		else
			# Jump to bookmark
			jump_to_bookmark "$bookmark_id"
		fi
		;;
	*)
		# Check dependencies
		check_jq

		# Jump to named bookmark or show error
		if [ ! -f "$BOOKMARK_FILE" ]; then
			echo -e "${RED}Error: No bookmarks found${NC}" >&2
			echo -e "${YELLOW}Create your first bookmark with: bookmark .${NC}" >&2
			exit 1
		fi

		jump_to_bookmark "$1"
		;;
	esac
}

# Run main function
main "$@"
