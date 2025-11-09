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
readonly MLH_CONFIG_FILE="$MLH_CONFIG_DIR/mlh.conf"
readonly MAX_UNNAMED_BOOKMARKS=10

# Load alias configuration from mlh.conf
BOOKMARK_ALIAS=""
if [ -f "$MLH_CONFIG_FILE" ]; then
	# Source the main config file to get BOOKMARK_ALIAS value
	# shellcheck source=/dev/null
	source "$MLH_CONFIG_FILE" 2>/dev/null || true
fi

# Determine command name for help messages (alias if configured, otherwise 'bookmark')
COMMAND_NAME="${BOOKMARK_ALIAS:-bookmark}"

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
		echo -e "${YELLOW}Or run: i jq${NC}" >&2
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

# Move bookmark to a different category
move_bookmark() {
	local name="$1"
	local new_category="$2"

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	# Check if bookmark exists
	local exists
	exists=$(jq --arg name "$name" '.bookmarks.named | any(.name == $name)' "$BOOKMARK_FILE" 2>/dev/null)

	if [ "$exists" != "true" ]; then
		echo -e "${RED}Error: Bookmark '$name' not found${NC}" >&2
		return 1
	fi

	# Update the category
	local temp_file
	temp_file=$(mktemp)

	jq --arg name "$name" \
		--arg category "$new_category" \
		'(.bookmarks.named[] | select(.name == $name) | .category) = $category' \
		"$BOOKMARK_FILE" >"$temp_file"

	mv "$temp_file" "$BOOKMARK_FILE"

	echo -e "${GREEN}✓ Moved bookmark:${NC} $name ${GRAY}→ Category:${NC} ${CYAN}$new_category${NC}"
}

# Remove a bookmark
remove_bookmark() {
	local name="$1"

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	# Check if it's a number (unnamed bookmark)
	if [[ "$name" =~ ^[0-9]+$ ]]; then
		local exists
		exists=$(jq --arg id "$name" '.bookmarks.unnamed | any(.id == ($id | tonumber))' "$BOOKMARK_FILE" 2>/dev/null)

		if [ "$exists" != "true" ]; then
			echo -e "${RED}Error: Bookmark #$name not found${NC}" >&2
			return 1
		fi

		# Remove unnamed bookmark and re-number remaining ones
		local temp_file
		temp_file=$(mktemp)

		jq --arg id "$name" '
			.bookmarks.unnamed |= (
				map(select(.id != ($id | tonumber))) | 
				to_entries | 
				map(.value.id = (.key + 1) | .value) |
				sort_by(.created) |
				reverse
			)
		' "$BOOKMARK_FILE" >"$temp_file"

		mv "$temp_file" "$BOOKMARK_FILE"

		echo -e "${GREEN}✓ Removed bookmark #$name (IDs re-numbered)${NC}"
	else
		# Check if named bookmark exists
		local exists
		exists=$(jq --arg name "$name" '.bookmarks.named | any(.name == $name)' "$BOOKMARK_FILE" 2>/dev/null)

		if [ "$exists" != "true" ]; then
			echo -e "${RED}Error: Bookmark '$name' not found${NC}" >&2
			return 1
		fi

		# Remove named bookmark
		local temp_file
		temp_file=$(mktemp)

		jq --arg name "$name" '.bookmarks.named |= map(select(.name != $name))' \
			"$BOOKMARK_FILE" >"$temp_file"

		mv "$temp_file" "$BOOKMARK_FILE"

		echo -e "${GREEN}✓ Removed bookmark:${NC} $name"
	fi
}

# Clear all unnamed bookmarks
clear_unnamed_bookmarks() {
	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	local count
	count=$(jq '.bookmarks.unnamed | length' "$BOOKMARK_FILE" 2>/dev/null)

	if [ "$count" -eq 0 ]; then
		echo -e "${YELLOW}No unnamed bookmarks to clear${NC}"
		return 0
	fi

	# Ask for confirmation
	echo -e "${YELLOW}⚠ This will remove all $count unnamed bookmarks${NC}"
	read -rp "Are you sure? [y/N]: " confirm

	if [[ "$confirm" =~ ^[Yy]$ ]]; then
		local temp_file
		temp_file=$(mktemp)

		jq '.bookmarks.unnamed = []' "$BOOKMARK_FILE" >"$temp_file"
		mv "$temp_file" "$BOOKMARK_FILE"

		echo -e "${GREEN}✓ Cleared $count unnamed bookmarks${NC}"
	else
		echo "Cancelled"
	fi
}

# Edit a bookmark
edit_bookmark() {
	local name="$1"

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	# Check if bookmark exists
	local exists
	exists=$(jq --arg name "$name" '.bookmarks.named | any(.name == $name)' "$BOOKMARK_FILE" 2>/dev/null)

	if [ "$exists" != "true" ]; then
		echo -e "${RED}Error: Bookmark '$name' not found${NC}" >&2
		return 1
	fi

	# Get current values
	local current_path current_category
	current_path=$(jq -r --arg name "$name" '.bookmarks.named[] | select(.name == $name) | .path' "$BOOKMARK_FILE" 2>/dev/null)
	current_category=$(jq -r --arg name "$name" '.bookmarks.named[] | select(.name == $name) | .category // ""' "$BOOKMARK_FILE" 2>/dev/null)

	echo -e "${CYAN}Editing bookmark:${NC} $name"
	echo -e "${GRAY}Current path:${NC} $current_path"
	if [ -n "$current_category" ]; then
		echo -e "${GRAY}Current category:${NC} $current_category"
	else
		echo -e "${GRAY}Current category:${NC} (none)"
	fi
	echo ""

	# Ask for new name
	echo -n "New name (leave empty to keep '$name'): "
	read -r new_name
	if [ -z "$new_name" ]; then
		new_name="$name"
	else
		# Validate new name
		if ! validate_name "$new_name"; then
			return 1
		fi
		# Check if new name conflicts with existing bookmark
		if [ "$new_name" != "$name" ]; then
			local name_exists
			name_exists=$(jq --arg name "$new_name" '.bookmarks.named | any(.name == $name)' "$BOOKMARK_FILE" 2>/dev/null)
			if [ "$name_exists" = "true" ]; then
				echo -e "${RED}Error: Bookmark '$new_name' already exists${NC}" >&2
				return 1
			fi
		fi
	fi

	# Ask for new path
	echo -n "New path (leave empty to keep current): "
	read -r new_path
	if [ -z "$new_path" ]; then
		new_path="$current_path"
	else
		# Expand ~ to home directory
		new_path="${new_path/#\~/$HOME}"
		# Convert to absolute path if relative
		if [[ ! "$new_path" = /* ]]; then
			new_path="$(cd "$(dirname "$new_path")" 2>/dev/null && pwd)/$(basename "$new_path")" || new_path="$current_path"
		fi
	fi

	# Ask for new category
	if [ -n "$current_category" ]; then
		echo -n "New category (leave empty to keep '$current_category', '-' to remove): "
		read -r new_category
		if [ -z "$new_category" ]; then
			new_category="$current_category"
		elif [ "$new_category" = "-" ]; then
			new_category=""
		fi
	else
		echo -n "Category (leave empty for none): "
		read -r new_category
	fi

	# Update the bookmark
	local temp_file
	temp_file=$(mktemp)

	if [ -n "$new_category" ]; then
		jq --arg old_name "$name" \
			--arg new_name "$new_name" \
			--arg path "$new_path" \
			--arg category "$new_category" \
			'(.bookmarks.named[] | select(.name == $old_name)) |= {name: $new_name, path: $path, category: $category, created, accessed, access_count}' \
			"$BOOKMARK_FILE" >"$temp_file"
	else
		jq --arg old_name "$name" \
			--arg new_name "$new_name" \
			--arg path "$new_path" \
			'(.bookmarks.named[] | select(.name == $old_name)) |= {name: $new_name, path: $path, created, accessed, access_count}' \
			"$BOOKMARK_FILE" >"$temp_file"
	fi

	mv "$temp_file" "$BOOKMARK_FILE"

	echo ""
	echo -e "${GREEN}✓ Updated bookmark${NC}"
	echo -e "  ${GRAY}Name:${NC} $new_name"
	echo -e "  ${GRAY}Path:${NC} $new_path"
	if [ -n "$new_category" ]; then
		echo -e "  ${GRAY}Category:${NC} ${CYAN}$new_category${NC}"
	fi
}

# Find bookmarks by pattern
find_bookmarks() {
	local pattern="$1"

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	if [ -z "$pattern" ]; then
		echo -e "${RED}Error: Search pattern required${NC}" >&2
		echo -e "${YELLOW}Usage: bookmark find <pattern>${NC}" >&2
		return 1
	fi

	echo -e "${CYAN}Searching for bookmarks matching:${NC} $pattern"
	echo ""

	# Search in named bookmarks
	local found_named=0
	local named_results
	# Convert pattern to lowercase for case-insensitive search
	local pattern_lower
	pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')

	named_results=$(jq -r --arg pattern "$pattern_lower" '
		.bookmarks.named[] | 
		select(
			(.name | ascii_downcase | contains($pattern)) or 
			(.path | ascii_downcase | contains($pattern)) or 
			((.category // "") | ascii_downcase | contains($pattern))
		) |
		"\(.name)|\(.path)|\(.category // "")"
	' "$BOOKMARK_FILE" 2>/dev/null)

	if [ -n "$named_results" ]; then
		echo -e "${BLUE}📂 Named Bookmarks${NC}"
		while IFS='|' read -r name path category; do
			if [ -n "$category" ]; then
				echo -e "  ${GREEN}[$name]${NC} in ${CYAN}$category${NC}"
			else
				echo -e "  ${GREEN}[$name]${NC}"
			fi
			echo -e "    ${GRAY}$path${NC}"
			found_named=1
		done <<<"$named_results"
		echo ""
	fi

	# Search in unnamed bookmarks
	local found_unnamed=0
	local unnamed_results
	unnamed_results=$(jq -r --arg pattern "$pattern_lower" '
		.bookmarks.unnamed[] | 
		select(.path | ascii_downcase | contains($pattern)) |
		"\(.id)|\(.path)"
	' "$BOOKMARK_FILE" 2>/dev/null)

	if [ -n "$unnamed_results" ]; then
		echo -e "${BLUE}📌 Numbered Bookmarks${NC}"
		while IFS='|' read -r id path; do
			echo -e "  ${YELLOW}#$id${NC} ${GRAY}$path${NC}"
			found_unnamed=1
		done <<<"$unnamed_results"
		echo ""
	fi

	if [ $found_named -eq 0 ] && [ $found_unnamed -eq 0 ]; then
		echo -e "${YELLOW}No bookmarks found matching '$pattern'${NC}"
		return 1
	fi
}

# Interactive list menu
interactive_list() {
	# Check if we have a TTY available
	# In WSL, /dev/tty might not exist, so we check stdout instead
	if [ ! -t 0 ] && [ ! -t 1 ]; then
		echo -e "${RED}Error: Interactive mode requires a terminal${NC}" >&2
		echo -e "${YELLOW}Hint: Run without redirection or pipes${NC}" >&2
		return 1
	fi

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	# Check if we have any bookmarks
	local named_count unnamed_count
	named_count=$(jq '.bookmarks.named | length' "$BOOKMARK_FILE" 2>/dev/null || echo "0")
	unnamed_count=$(jq '.bookmarks.unnamed | length' "$BOOKMARK_FILE" 2>/dev/null || echo "0")

	if [ "$named_count" -eq 0 ] && [ "$unnamed_count" -eq 0 ]; then
		echo -e "${YELLOW}No bookmarks yet. Use 'bookmark .' to save current directory.${NC}"
		return 0
	fi

	# Build hierarchical list
	local -a entries
	local -a entry_ids
	local -a entry_types
	local idx=0

	# Group named bookmarks by category
	local categories
	categories=$(jq -r '.bookmarks.named | group_by(.category // "Uncategorized") | .[] | .[0].category // "Uncategorized"' "$BOOKMARK_FILE" 2>/dev/null | sort -u 2>/dev/null) || categories=""

	# Add category headers and bookmarks
	if [ -n "$categories" ]; then
		while IFS= read -r category || [ -n "$category" ]; do
			[ -z "$category" ] && break
			if [ "$category" != "null" ]; then
				# Add bookmarks in this category
				local bookmark_data
				bookmark_data=$(jq -r --arg cat "$category" '.bookmarks.named[] | select((.category // "Uncategorized") == $cat) | "\(.name)|\(.path)|\(.created)"' "$BOOKMARK_FILE" 2>/dev/null) || bookmark_data=""

				if [ -n "$bookmark_data" ]; then
					while IFS='|' read -r name path created || [ -n "$name" ]; do
						[ -z "$name" ] && break
						if [ "$name" != "null" ]; then
							entries+=("named|$name|$path|$category|$created")
							entry_ids+=("$name")
							entry_types+=("named")
							((idx++)) || true
						fi
					done <<<"$bookmark_data"
				fi
			fi
		done <<<"$categories"
	fi

	# Add unnamed bookmarks
	if [ "$unnamed_count" -gt 0 ]; then
		local unnamed_data
		unnamed_data=$(jq -r '.bookmarks.unnamed[] | "\(.id)|\(.path)|\(.created)"' "$BOOKMARK_FILE" 2>/dev/null) || unnamed_data=""

		if [ -n "$unnamed_data" ]; then
			while IFS='|' read -r id path created || [ -n "$id" ]; do
				[ -z "$id" ] && break
				if [ "$id" != "null" ]; then
					entries+=("unnamed|$id|$path||$created")
					entry_ids+=("$id")
					entry_types+=("unnamed")
					((idx++)) || true
				fi
			done <<<"$unnamed_data"
		fi
	fi

	if [ ${#entries[@]} -eq 0 ]; then
		echo -e "${YELLOW}No bookmarks to display${NC}"
		return 0
	fi

	local selected=0
	local total=${#entries[@]}

	# Display function
	show_menu() {
		# Clear screen only if we have a TTY
		# In WSL, clear might fail, so we use ANSI escape codes as fallback
		if [ -t 1 ]; then
			clear 2>/dev/null || printf '\033[2J\033[H' 2>/dev/null || true
		fi
		local display_count=$((named_count + unnamed_count))
		echo "┌─────────────────────────────────────────────────────────────────┐"
		printf "│%*s📚 Bookmarks (%d total)%*s│\n" 22 "" $display_count 22 ""
		echo "└─────────────────────────────────────────────────────────────────┘"
		echo ""

		local current_category=""
		local prev_category_parts=()
		for i in "${!entries[@]}"; do
			IFS='|' read -r type id_or_name path category created <<<"${entries[$i]}"

			# Show category header (hierarchical)
			if [ "$type" = "named" ] && [ "$category" != "$current_category" ]; then
				# Handle Uncategorized specially
				if [ -z "$category" ] || [ "$category" = "null" ]; then
					if [ "$current_category" != "Uncategorized" ]; then
						current_category="Uncategorized"
						prev_category_parts=()
						echo -e "${GRAY}📁 Uncategorized${NC}"
					fi
				else
					current_category="$category"
					# Split category by /
					IFS='/' read -ra category_parts <<<"$category"

					# Print each level of hierarchy that's new
					for level in "${!category_parts[@]}"; do
						# Check if this level is new compared to previous category
						if [ "$level" -ge "${#prev_category_parts[@]}" ] || [ "${category_parts[$level]}" != "${prev_category_parts[$level]:-}" ]; then
							# Build indent for this level
							local indent=""
							for ((j = 0; j < level; j++)); do
								indent="  $indent"
							done
							echo -e "${indent}${BLUE}📂 ${category_parts[$level]}${NC}"
						fi
					done

					# Update prev_category_parts for next iteration
					prev_category_parts=("${category_parts[@]}")
				fi
			elif [ "$type" = "unnamed" ] && [ "$current_category" != "📌 Recent (Unnamed)" ]; then
				current_category="📌 Recent (Unnamed)"
				prev_category_parts=()
				echo ""
				echo -e "${BLUE}$current_category${NC}"
			fi

			# Calculate indent for bookmark based on category depth
			local bookmark_indent=""
			if [ "$type" = "named" ] && [ -n "$category" ] && [ "$category" != "null" ]; then
				IFS='/' read -ra category_parts <<<"$category"
				for ((j = 0; j < ${#category_parts[@]}; j++)); do
					bookmark_indent="  $bookmark_indent"
				done
			fi

			# Show bookmark
			if [ "$i" -eq "$selected" ]; then
				echo -en "${bookmark_indent}${GREEN}▶ "
			else
				echo -n "${bookmark_indent}  "
			fi

			if [ "$type" = "named" ]; then
				printf "${GREEN}[%s]${NC}" "$id_or_name"
				# Pad to 15 chars
				local padding=$((15 - ${#id_or_name}))
				printf "%*s" $padding ""
				printf "${GRAY}%s${NC}" "$path"
				# Show date
				local date_only="${created%%T*}"
				printf "  %s" "$date_only"
			else
				printf "${YELLOW}%2s:${NC}" "$id_or_name"
				printf " ${GRAY}%s${NC}" "$path"
				local date_time="${created%%.*}"
				printf "  %s" "${date_time/T/ }"
			fi
			echo ""
		done

		echo ""
		echo "────────────────────────────────────────────────────────────────────"
		echo -e "${YELLOW}j/k or ↑/↓:${NC} Navigate | ${YELLOW}Enter:${NC} Jump | ${YELLOW}d:${NC} Delete | ${YELLOW}e:${NC} Edit | ${YELLOW}h:${NC} Help | ${YELLOW}q:${NC} Quit"
	}

	# Show help
	show_help_menu() {
		clear
		echo "┌─────────────────────────────────────────────────────────────────┐"
		printf "│%*s📚 Interactive Bookmarks - Help%*s│\n" 18 "" 18 ""
		echo "└─────────────────────────────────────────────────────────────────┘"
		echo ""
		echo -e "${CYAN}Navigation:${NC}"
		echo "  j, ↓          Move down"
		echo "  k, ↑          Move up"
		echo ""
		echo -e "${CYAN}Actions:${NC}"
		echo "  Enter         Jump to selected bookmark"
		echo "  e             Edit bookmark (name/path/category)"
		echo "  d             Delete bookmark"
		echo "  r             Refresh list"
		echo "  h             Show this help"
		echo "  q             Quit to shell"
		echo ""
		echo -e "${CYAN}Tips:${NC}"
		echo "  • Numbered bookmarks can be converted to named via edit"
		echo "  • Deleted numbered bookmarks cause re-numbering (2→1)"
		echo "  • Press 'r' to reload after external changes"
		echo ""
		if [ -t 0 ]; then
			read -rp "Press any key to continue..." -n1
		elif [ -e /dev/tty ]; then
			read -rp "Press any key to continue..." -n1 </dev/tty
		else
			read -rp "Press any key to continue..." -n1
		fi
	}

	# Main loop
	while true; do
		# Show menu - ensure it always displays something
		if ! show_menu 2>/dev/null; then
			# If show_menu fails silently, try again without clear
			show_menu 2>&1 || {
				echo -e "${RED}Error: Failed to display menu${NC}" >&2
				return 1
			}
		fi

		# Read key with proper handling
		# Interactive mode - wait for user input (no timeout)
		# In WSL, prefer stdin if it's a TTY, otherwise try /dev/tty
		key=""
		if [ -t 0 ]; then
			# Direct TTY - use normal read
			if ! read -rsn1 key 2>/dev/null; then
				continue
			fi
		elif [ -e /dev/tty ]; then
			# Not a TTY but /dev/tty exists - read from /dev/tty
			if ! read -rsn1 key </dev/tty 2>/dev/null; then
				continue
			fi
		else
			# WSL fallback - try reading from stdin anyway
			if ! read -rsn1 key 2>/dev/null; then
				continue
			fi
		fi

		# Handle arrow keys (escape sequences)
		if [[ $key == $'\x1b' ]]; then
			rest=""
			if [ -t 0 ]; then
				read -rsn1 -t 0.5 rest 2>/dev/null || rest=""
			elif [ -e /dev/tty ]; then
				read -rsn1 -t 0.5 rest </dev/tty 2>/dev/null || rest=""
			else
				read -rsn1 -t 0.5 rest 2>/dev/null || rest=""
			fi
			if [[ $rest == '[' ]]; then
				# Read the actual arrow key character
				if [ -t 0 ]; then
					read -rsn1 -t 0.5 rest2 2>/dev/null || rest2=""
				elif [ -e /dev/tty ]; then
					read -rsn1 -t 0.5 rest2 </dev/tty 2>/dev/null || rest2=""
				else
					read -rsn1 -t 0.5 rest2 2>/dev/null || rest2=""
				fi
				if [[ $rest2 == 'A' ]]; then
					key="UP"
				elif [[ $rest2 == 'B' ]]; then
					key="DOWN"
				elif [[ $rest2 == 'C' ]]; then
					key="RIGHT"
				elif [[ $rest2 == 'D' ]]; then
					key="LEFT"
				else
					# Unknown escape sequence - treat as quit
					key="q"
				fi
			else
				# ESC key alone - treat as quit
				key="q"
			fi
		fi

		case "$key" in
		'UP' | 'k' | 'K') # Up arrow or k
			((selected--)) || true
			if [ "$selected" -lt 0 ]; then
				selected=$((total - 1))
			fi
			;;
		'DOWN' | 'j' | 'J') # Down arrow or j
			((selected++)) || true
			if [ "$selected" -ge "$total" ]; then
				selected=0
			fi
			;;
		'') # Enter
			local sel_type="${entry_types[$selected]}"
			local sel_id="${entry_ids[$selected]}"

			# Clear screen before exiting interactive mode
			clear 2>/dev/null || printf '\033[2J\033[H' 2>/dev/null || true

			# Jump to bookmark - get the path
			local bookmark_path
			bookmark_path=$(jq -r --arg id "$sel_id" '
				(.bookmarks.unnamed[] | select(.id == (try ($id | tonumber) catch null)) | .path) //
				(.bookmarks.named[] | select(.name == $id) | .path) //
				empty
			' "$BOOKMARK_FILE" 2>/dev/null)

			if [ -z "$bookmark_path" ] || [ "$bookmark_path" = "null" ]; then
				echo -e "${RED}Error: Bookmark '$sel_id' not found${NC}" >&2
				return 1
			fi

			# Check if path exists
			if [ ! -d "$bookmark_path" ]; then
				echo -e "${YELLOW}Warning: Path no longer exists: $bookmark_path${NC}" >&2
				return 1
			fi

			# Write cd command to temp file (ranger-style)
			# Wrapper function will check this file and source it
			# Use environment variable if set (unique temp file per invocation)
			# Otherwise fall back to fixed path (for backward compatibility)
			local tmp_cd_file="${MLH_BOOKMARK_CD_FILE:-/tmp/bookmark-cd-${USER:-$(id -un)}}"

			# Ensure temp file directory exists and is writable
			local tmp_dir
			tmp_dir=$(dirname "$tmp_cd_file")
			if [ ! -d "$tmp_dir" ] || [ ! -w "$tmp_dir" ]; then
				echo -e "${RED}Error: Temp directory not writable: $tmp_dir${NC}" >&2
				return 1
			fi

			# Support multiple selections in same session: append sequence number
			# Count existing sequence files to generate next number
			local sequence_num=1
			while [ -f "${tmp_cd_file}.${sequence_num}" ]; do
				sequence_num=$((sequence_num + 1))
			done
			local tmp_cd_file_seq="${tmp_cd_file}.${sequence_num}"

			# Write cd command to temp file (use printf for better reliability)
			# Use atomic write: write to temp file first, then move to final location
			local tmp_write_file="${tmp_cd_file_seq}.tmp"
			printf 'cd "%s"\n' "$bookmark_path" >"$tmp_write_file" 2>/dev/null || {
				echo -e "${RED}Error: Failed to write temp file${NC}" >&2
				return 1
			}

			# Atomically move to final location
			mv "$tmp_write_file" "$tmp_cd_file_seq" 2>/dev/null || {
				echo -e "${RED}Error: Failed to move temp file${NC}" >&2
				rm -f "$tmp_write_file" 2>/dev/null || true
				return 1
			}

			# Verify file was written and has content
			if [ ! -f "$tmp_cd_file_seq" ] || [ ! -s "$tmp_cd_file_seq" ]; then
				echo -e "${RED}Error: Temp file not created or empty${NC}" >&2
				return 1
			fi

			# Ensure file is readable
			if [ ! -r "$tmp_cd_file_seq" ]; then
				echo -e "${RED}Error: Temp file not readable${NC}" >&2
				return 1
			fi

			# Sync to ensure file is written to disk
			sync 2>/dev/null || true

			echo -e "${GREEN}→${NC} $bookmark_path" >&2

			# Exit interactive mode after selection
			# Each invocation handles one selection
			return 0
			;;
		'd' | 'D') # Delete
			local sel_type="${entry_types[$selected]}"
			local sel_id="${entry_ids[$selected]}"
			echo ""
			if [ -t 0 ]; then
				read -rp "Delete bookmark [$sel_id]? [y/N]: " confirm
			elif [ -e /dev/tty ]; then
				read -rp "Delete bookmark [$sel_id]? [y/N]: " confirm </dev/tty
			else
				read -rp "Delete bookmark [$sel_id]? [y/N]: " confirm
			fi
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				remove_bookmark "$sel_id"
				echo -e "${GREEN}✓ Deleted${NC}"
				sleep 1
				# Reload
				interactive_list
				return $?
			fi
			;;
		'e' | 'E') # Edit
			local sel_type="${entry_types[$selected]}"
			local sel_id="${entry_ids[$selected]}"

			if [ "$sel_type" = "unnamed" ]; then
				# Convert to named
				IFS='|' read -r type id path _ created <<<"${entries[$selected]}"
				echo ""
				if [ -t 0 ]; then
					read -rp "Enter name for bookmark #$sel_id: " new_name
				elif [ -e /dev/tty ]; then
					read -rp "Enter name for bookmark #$sel_id: " new_name </dev/tty
				else
					read -rp "Enter name for bookmark #$sel_id: " new_name
				fi
				if [ -n "$new_name" ] && validate_name "$new_name"; then
					if [ -t 0 ]; then
						read -rp "Category (leave empty for none): " category
					elif [ -e /dev/tty ]; then
						read -rp "Category (leave empty for none): " category </dev/tty
					else
						read -rp "Category (leave empty for none): " category
					fi
					rename_bookmark "$sel_id" "$new_name" "$category"
					echo -e "${GREEN}✓ Converted to named bookmark${NC}"
					sleep 1
					interactive_list
					return $?
				fi
			else
				edit_bookmark "$sel_id"
				interactive_list
				return $?
			fi
			;;
		'r' | 'R') # Refresh
			interactive_list
			return $?
			;;
		'h' | 'H') # Help
			show_help_menu
			;;
		'q' | 'Q' | $'\x03') # Quit or Ctrl+C
			clear
			return 0
			;;
		esac
	done
}

# List all bookmarks
list_bookmarks() {
	local filter_category="${1:-}"
	local limit=""
	local non_interactive=false

	# Check for interactive flag (explicit)
	if [ "$filter_category" = "-i" ] || [ "$filter_category" = "--interactive" ]; then
		interactive_list
		local exit_code=$?
		return $exit_code
	fi

	# Check for non-interactive flag
	if [ "$filter_category" = "-n" ] || [ "$filter_category" = "--non-interactive" ]; then
		non_interactive=true
		filter_category="${2:-}"
	fi

	# Check if argument is a number (limit) or string (category filter)
	if [ -n "$filter_category" ] && [[ "$filter_category" =~ ^[0-9]+$ ]]; then
		limit="$filter_category"
		filter_category=""
	fi

	# NEW: Default to interactive mode when no arguments and no explicit -n flag
	if [ "$non_interactive" = false ] && [ -z "$filter_category" ] && [ -z "$limit" ]; then
		interactive_list
		local exit_code=$?
		return $exit_code
	fi

	[ ! -f "$BOOKMARK_FILE" ] && init_bookmark_file

	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	if [ -n "$filter_category" ]; then
		echo -e "${CYAN}📚 Bookmarks in category: ${YELLOW}$filter_category${NC}"
	else
		echo -e "${CYAN}📚 Bookmarks${NC}"
	fi
	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo ""

	# Named bookmarks - grouped by category
	local named_count
	if [ -n "$filter_category" ]; then
		named_count=$(jq --arg cat "$filter_category" '[.bookmarks.named[] | select(.category == $cat or (.category // "" | startswith($cat + "/")))] | length' "$BOOKMARK_FILE" 2>/dev/null)
	else
		named_count=$(jq '.bookmarks.named | length' "$BOOKMARK_FILE" 2>/dev/null)
	fi

	if [ "$named_count" -gt 0 ]; then
		echo -e "${BLUE}📂 Named Bookmarks${NC}"

		# Group bookmarks by category and display hierarchically
		local categories
		if [ -n "$filter_category" ]; then
			categories=$(jq -r --arg cat "$filter_category" '[.bookmarks.named[] | select(.category == $cat or (.category // "" | startswith($cat + "/")))] | group_by(.category // "Uncategorized") | .[] | .[0].category // "Uncategorized"' "$BOOKMARK_FILE" 2>/dev/null | sort -u)
		else
			categories=$(jq -r '.bookmarks.named | group_by(.category // "Uncategorized") | .[] | .[0].category // "Uncategorized"' "$BOOKMARK_FILE" 2>/dev/null | sort)
		fi

		# Display categories hierarchically
		local prev_parts
		prev_parts=()
		while IFS= read -r category; do
			if [ -n "$category" ] && [ "$category" != "null" ]; then
				# Handle Uncategorized specially
				if [ "$category" = "Uncategorized" ]; then
					echo -e "  ${GRAY}📁 Uncategorized${NC}"
					# Show bookmarks
					jq -r '.bookmarks.named[] | select((.category // "") == "") |
						   "      [\(.name)]  \(.path)  \(.created | split("T")[0])"' \
						"$BOOKMARK_FILE" 2>/dev/null | while IFS= read -r line; do
						local path
						path=$(echo "$line" | awk '{print $2}')
						if [ -d "$path" ]; then
							echo -e "$line"
						else
							echo -e "$line ${YELLOW}⚠${NC}"
						fi
					done
					prev_parts=()
					continue
				fi

				# Split category by /
				IFS='/' read -ra parts <<<"$category"

				# Print each level of hierarchy
				for i in "${!parts[@]}"; do
					# Check if this level is new compared to previous category
					if [ "$i" -ge ${#prev_parts[@]} ] || [ "${parts[$i]}" != "${prev_parts[$i]}" ]; then
						local indent=""
						for ((j = 0; j < i; j++)); do
							indent="  $indent"
						done
						echo -e "  $indent${GREEN}📂 ${parts[$i]}${NC}"
					fi
				done

				# Show bookmarks in this exact category
				local bookmark_indent=""
				for ((j = 0; j < ${#parts[@]}; j++)); do
					bookmark_indent="  $bookmark_indent"
				done

				jq -r --arg cat "$category" '.bookmarks.named[] | select(.category == $cat) |
				   "[\(.name)]  \(.path)  \(.created | split("T")[0])"' \
					"$BOOKMARK_FILE" 2>/dev/null | while IFS= read -r line; do
					local path
					path=$(echo "$line" | awk '{print $2}')
					if [ -d "$path" ]; then
						echo -e "  $bookmark_indent  $line"
					else
						echo -e "  $bookmark_indent  $line ${YELLOW}⚠${NC}"
					fi
				done

				# Update prev_parts for next iteration
				prev_parts=("${parts[@]}")
			fi
		done <<<"$categories"
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
	echo -e "${CYAN}bookmark${NC} - Quick directory bookmark system (v$VERSION)"
	echo ""

	# Show shortcut info if alias is configured
	if [ -n "$BOOKMARK_ALIAS" ]; then
		echo -e "${GREEN}Shortcut:${NC} You can use '${CYAN}${BOOKMARK_ALIAS}${NC}' instead of 'bookmark'"
		echo ""
	fi

	echo "Usage:"
	cat <<EOF
  $COMMAND_NAME .                    Save current directory as numbered bookmark
  $COMMAND_NAME <number>             Jump to numbered bookmark
  $COMMAND_NAME <name>               Jump to named bookmark
  $COMMAND_NAME --help               Show this help
EOF
	echo ""
	echo "Commands:"
	cat <<EOF
  Save:
    $COMMAND_NAME .                    Save current directory (becomes bookmark #1)
    $COMMAND_NAME . -n <name>          Save with name
    $COMMAND_NAME . -n <name> in <cat> Save with category
    $COMMAND_NAME <number> -n <name>   Rename numbered bookmark to name

  Navigate:
    $COMMAND_NAME <number>             Jump to numbered bookmark (1-10)
    $COMMAND_NAME <name>               Jump to named bookmark

  List:
    $COMMAND_NAME list                 Interactive menu (default, arrow keys)
    $COMMAND_NAME list -n              Non-interactive list (simple output)
    $COMMAND_NAME list <category>      Interactive list filtered by category
    $COMMAND_NAME list -n <category>   Non-interactive list for category
    $COMMAND_NAME list <N>             List last N unnamed bookmarks

  Manage:
    $COMMAND_NAME mv <name> to <cat>   Move bookmark to category
    $COMMAND_NAME edit <name>          Edit bookmark (name/path/category)
    $COMMAND_NAME rm <name|number>     Remove a bookmark
    $COMMAND_NAME clear                Clear all numbered bookmarks
    $COMMAND_NAME find <pattern>       Search bookmarks by pattern
EOF
	echo ""
	echo "Features:"
	cat <<EOF
  • Stack-based numbered bookmarks (max 10, LIFO)
  • Named bookmarks with categories
  • Interactive menu with arrow key navigation
  • Hierarchical categories (e.g., projects/linux/tools)
  • Path validation with warnings (⚠ symbol)
  • Command name conflict detection
  • JSON storage: $BOOKMARK_FILE
EOF
	echo ""
	echo "Notes:"
	cat <<EOF
  • Symbols: ⚠ (path missing), → (navigating), ✓ (saved)
  • Interactive mode: Use ↑/↓ or j/k to navigate, Enter to jump, e to edit, d to delete, h for help
  • Numbered bookmarks are LIFO (last added becomes #1)
  • Category names support slashes for hierarchy (e.g., work/projects/java)
  • Configure custom alias in: ~/.mylinuxhelper/mlh.conf (BOOKMARK_ALIAS=bm)
EOF
	echo ""
	echo "Examples:"
	echo -e "  ${GREEN}# Quick numbered bookmarks${NC}"
	cat <<EOF
  $COMMAND_NAME .                    # Save current dir (becomes #1)
  cd /some/other/path
  $COMMAND_NAME .                    # Save another (becomes #1, previous → #2)
  $COMMAND_NAME 1                    # Jump to most recent
  $COMMAND_NAME 2                    # Jump to second most recent
EOF
	echo ""
	echo -e "  ${GREEN}# Named bookmarks${NC}"
	cat <<EOF
  $COMMAND_NAME . -n myproject       # Save current dir as 'myproject'
  $COMMAND_NAME myproject            # Jump to myproject
  $COMMAND_NAME 1 -n webapp          # Rename bookmark #1 to 'webapp'
EOF
	echo ""
	echo -e "  ${GREEN}# Categorized bookmarks${NC}"
	cat <<EOF
  $COMMAND_NAME . -n mlh in projects/linux    # Save with category
  $COMMAND_NAME . -n api in projects/java     # Another category
  $COMMAND_NAME mv mlh to tools               # Move to different category
EOF
	echo ""
	echo -e "  ${GREEN}# List and navigate${NC}"
	cat <<EOF
  $COMMAND_NAME list                 # Interactive menu (default)
  $COMMAND_NAME list -n              # Non-interactive list
  $COMMAND_NAME list projects        # Interactive, filtered by category
  $COMMAND_NAME list -n projects     # Non-interactive, filtered
  $COMMAND_NAME list 5               # Show last 5 numbered bookmarks
EOF
	echo ""
	echo -e "  ${GREEN}# Edit and search${NC}"
	cat <<EOF
  $COMMAND_NAME edit myproject       # Edit bookmark interactively
  $COMMAND_NAME find proj            # Search bookmarks by pattern
  $COMMAND_NAME find /home           # Search by path
  $COMMAND_NAME rm myproject         # Remove named bookmark
  $COMMAND_NAME rm 1                 # Remove numbered bookmark
  $COMMAND_NAME clear                # Clear all numbered bookmarks (asks confirmation)
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
		# Pass all remaining arguments to list_bookmarks
		list_bookmarks "$@"
		exit 0
		;;
	mv)
		# bookmark mv <name> to <category>
		check_jq
		if [ $# -lt 4 ] || [ "$3" != "to" ]; then
			echo -e "${RED}Error: Invalid syntax${NC}" >&2
			echo -e "${YELLOW}Usage: bookmark mv <name> to <category>${NC}" >&2
			exit 1
		fi
		move_bookmark "$2" "$4"
		exit 0
		;;
	rm)
		# bookmark rm <name|number>
		check_jq
		if [ $# -lt 2 ]; then
			echo -e "${RED}Error: Missing bookmark name or number${NC}" >&2
			echo -e "${YELLOW}Usage: bookmark rm <name|number>${NC}" >&2
			exit 1
		fi
		remove_bookmark "$2"
		exit 0
		;;
	clear)
		# bookmark clear - clear all unnamed bookmarks
		check_jq
		clear_unnamed_bookmarks
		exit 0
		;;
	edit)
		# bookmark edit <name>
		check_jq
		if [ $# -lt 2 ]; then
			echo -e "${RED}Error: Missing bookmark name${NC}" >&2
			echo -e "${YELLOW}Usage: bookmark edit <name>${NC}" >&2
			exit 1
		fi
		edit_bookmark "$2"
		exit 0
		;;
	find)
		# bookmark find <pattern>
		check_jq
		if [ $# -lt 2 ]; then
			echo -e "${RED}Error: Missing search pattern${NC}" >&2
			echo -e "${YELLOW}Usage: bookmark find <pattern>${NC}" >&2
			exit 1
		fi
		find_bookmarks "$2"
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
