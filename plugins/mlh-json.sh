#!/bin/bash

# Resolve own real path (follows symlinks) to find repo root
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  TARGET="$(readlink "$SOURCE")"
  if [[ $TARGET == /* ]]; then
    SOURCE="$TARGET"
  else
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$DIR/$TARGET"
  fi
done
PLUGIN_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ROOT_DIR="$(dirname "$PLUGIN_DIR")"

# Load installer function i (for ensuring jq)
# shellcheck source=/dev/null
. "$ROOT_DIR/install.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq is not installed. Installing...${NC}"
        i jq || {
            echo -e "${RED}Error: failed to install jq${NC}"
            exit 1
        }
    fi
}

# Note: validate_json is now delegated to isjsonvalid.sh
# This function is kept for backward compatibility but redirects to isjsonvalid
validate_json() {
    local file="$1"
    # Delegate to isjsonvalid.sh with --detail flag
    "$PLUGIN_DIR/isjsonvalid.sh" --detail "$file"
}

# Function to get all JSON paths recursively
get_all_paths() {
    local file="$1"
    jq -r 'paths(scalars) as $p | "\($p | map(tostring) | join("."))"' "$file" 2>/dev/null
}

# Function to get all array paths
get_all_array_values() {
    local file="$1"
    jq -r 'paths(arrays) as $p | ($p | map(tostring) | join(".")) as $path | getpath($p)[] | "\($path)[\(.)]: \(.)"' "$file" 2>/dev/null
}

# Function to get all array and object key names
get_all_keys() {
    local file="$1"
    # Get all paths including arrays and objects, extract their key names
    jq -r 'paths as $p | $p | map(tostring) | join(".")' "$file" 2>/dev/null
}

# Function to format path with quoted segments
format_path() {
    local path="$1"
    # Split by dots and wrap each segment in quotes: Query.StudyDate -> "Query"."StudyDate"
    echo "$path" | awk -F'.' '{for(i=1; i<=NF; i++) printf "\"%s\"%s", $i, (i<NF ? "." : "")}'
}

# Function to format array path and value
format_array_output() {
    local path="$1"
    local value="$2"
    # For arrays, show: "ArrayPath": ["value"]
    echo "\"${path}\": [\"${value}\"]"
}

# Function to format object path and value
format_object_output() {
    local path="$1"
    local value="$2"
    # For all types: "Path"."Key": value
    # jq -c already returns valid JSON (strings with quotes, arrays/objects without extra quotes)
    local formatted_path=$(format_path "$path")
    echo "${formatted_path}: ${value}"
}

# Function to perform fuzzy search on field names
fuzzy_search() {
    local query="$1"
    local file="$2"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File '$file' not found.${NC}"
        exit 1
    fi

    # Check if file is valid JSON
    if ! jq empty "$file" 2>/dev/null; then
        echo -e "${RED}Error: Invalid JSON in file '$file'${NC}"
        exit 1
    fi

    # Check if query contains path hint (e.g., "q.studyd" or "RequestedTags.study")
    local path_hint=""
    local field_query="$query"

    if [[ "$query" == *.* ]]; then
        # Split by first dot
        path_hint=$(echo "$query" | cut -d'.' -f1)
        field_query=$(echo "$query" | cut -d'.' -f2-)
    fi

    # Convert to lowercase for case-insensitive matching
    local query_lower=$(echo "$field_query" | tr '[:upper:]' '[:lower:]')
    local path_hint_lower=$(echo "$path_hint" | tr '[:upper:]' '[:lower:]')

    # Array to store matches
    declare -a matches=()
    declare -a match_paths=()
    declare -a match_values=()

    # Search in ALL keys (including arrays and objects) and get their values
    while IFS= read -r path; do
        # Skip empty paths
        [[ -z "$path" ]] && continue

        # If path hint is provided, check if path starts with hint
        if [[ -n "$path_hint" ]]; then
            local path_start=$(echo "$path" | cut -d'.' -f1)
            local path_start_lower=$(echo "$path_start" | tr '[:upper:]' '[:lower:]')
            # Skip if path doesn't match hint
            if [[ "$path_start_lower" != *"$path_hint_lower"* ]]; then
                continue
            fi
        fi

        # Extract the last part of the path (the key name)
        local key=$(echo "$path" | grep -oE '[^.]+$')
        local key_lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')

        # Fuzzy match: check if query is contained in key
        if [[ "$key_lower" == *"$query_lower"* ]]; then
            local value=$(jq -c ".$path" "$file" 2>/dev/null)
            # Skip if we already added this path (to avoid duplicates)
            local already_added=false
            for mp in "${match_paths[@]}"; do
                if [[ "$mp" == "$path" ]]; then
                    already_added=true
                    break
                fi
            done

            if [[ "$already_added" == false ]]; then
                local formatted_output=$(format_object_output "$path" "$value")
                matches+=("$formatted_output")
                match_paths+=("$path")
                match_values+=("$value")
            fi
        fi
    done < <(get_all_keys "$file")

    # Search in array values
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract array path and value
            local array_path=$(echo "$line" | cut -d'[' -f1)
            local array_value=$(echo "$line" | grep -oE '\[.*\]:' | sed 's/\[//g;s/\]://g')
            local actual_value=$(echo "$line" | cut -d':' -f2- | sed 's/^ //g')

            # If path hint is provided, check if path starts with hint
            if [[ -n "$path_hint" ]]; then
                local array_path_start=$(echo "$array_path" | cut -d'.' -f1)
                local array_path_start_lower=$(echo "$array_path_start" | tr '[:upper:]' '[:lower:]')
                # Skip if path doesn't match hint
                if [[ "$array_path_start_lower" != *"$path_hint_lower"* ]]; then
                    continue
                fi
            fi

            # Check if value matches query (case-insensitive)
            local value_lower=$(echo "$actual_value" | tr '[:upper:]' '[:lower:]')
            if [[ "$value_lower" == *"$query_lower"* ]]; then
                local formatted_output=$(format_array_output "$array_path" "$actual_value")
                matches+=("$formatted_output")
                match_paths+=("$array_path")
                match_values+=("$actual_value")
            fi
        fi
    done < <(get_all_array_values "$file")

    # Display results
    if [[ ${#matches[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No matches found for query: '$query'${NC}"
        exit 0
    elif [[ ${#matches[@]} -eq 1 ]]; then
        echo -e "${GREEN}${matches[0]}${NC}"
    else
        # Multiple matches - show interactive menu
        echo -e "${CYAN}Found ${#matches[@]} matches for '$query':${NC}"
        echo ""

        for i in "${!matches[@]}"; do
            echo -e "${YELLOW}$((i+1)).${NC} ${matches[$i]}"
        done

        echo ""
        echo -e "${BLUE}Select a number (1-${#matches[@]}) or press Enter to show all:${NC}"
        read -r selection

        if [[ -z "$selection" ]]; then
            # Show all
            echo ""
            echo -e "${GREEN}All matches:${NC}"
            for match in "${matches[@]}"; do
                echo -e "  $match"
            done
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#matches[@]} ]]; then
            # Show selected item
            local idx=$((selection-1))
            echo ""
            echo -e "${GREEN}${matches[$idx]}${NC}"
        else
            echo -e "${RED}Invalid selection.${NC}"
            exit 1
        fi
    fi
}

# Function to show help
show_help() {
    cat <<'EOF'
JSON Operations - Validate and search JSON files

Usage:
  isjsonvalid [OPTIONS] <file>                Validate JSON file
  mlh json --isvalid [OPTIONS] <file>         Validate JSON file
  mlh json get <field> from <file>            Search for a field in JSON file
  mlh json --help                             Show this help

Validation Commands:
  isjsonvalid <file>                Quick validation (Yes/No output)
  isjsonvalid -d <file>             Detailed validation with colors
  isjsonvalid --detail <file>       Detailed validation with colors

  mlh json --isvalid <file>         Detailed validation (default)
  mlh json --isvalid -d <file>      Detailed validation with colors
  mlh json --isvalid --detail <file> Detailed validation with colors

Search Commands:
  mlh json get <field> from <file>  Search for a field (fuzzy match, case-insensitive)

Features:
  - Validates JSON files with quick or detailed output
  - Fuzzy field name matching (case-insensitive)
  - Partial key matching (e.g., "req" finds "RequestedTags")
  - Path hint support (e.g., "q.field" searches only under "Query")
  - Interactive menu for multiple matches
  - Shows full JSON path to each field
  - Searches ALL JSON keys (arrays, objects, scalars)

Examples:
  # Sample JSON file (users.json):
  # {
  #   "users": [
  #     {"name": "John", "email": "john@example.com", "age": 30, "language": "en"},
  #     {"name": "Jane", "email": "jane@example.com", "age": 25, "language": "fr"}
  #   ],
  #   "settings": {
  #     "theme": "dark",
  #     "language": "en"
  #   }
  # }

  # Quick validation (Yes/No)
  isjsonvalid users.json
  # Output: Yes

  # Detailed validation
  isjsonvalid -d users.json
  # Output: ✓ Valid JSON

  # Detailed validation via mlh json
  mlh json --isvalid users.json
  mlh json --isvalid -d users.json
  # Output: ✓ Valid JSON

  # Search for a field
  mlh json get name from users.json
  # Output: "users"."name": "John"

  # Partial/fuzzy matching
  mlh json get mail from users.json
  # Finds "email": "users"."email": "john@example.com"

  # Multiple matches - shows interactive menu:
  mlh json get lang from users.json
  # Output:
  #   Found 3 matches for 'lang':
  #   1. "users"."language": "en"
  #   2. "users"."language": "fr"
  #   3. "settings"."language": "en"
  #   Select a number (1-3) or press Enter to show all:

  # Path hint - targeted search (no menu!)
  mlh json get sett.lang from users.json
  # Output: "settings"."language": "en"
EOF
}

# Main function
main() {
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_help
        exit 0
    fi

    # Check jq only when actually needed (not for help)
    check_jq

    case "$1" in
        --isvalid)
            shift
            # Forward arguments to isjsonvalid.sh
            # mlh json --isvalid defaults to detailed output
            # unless user explicitly provides -d or --detail flag
            if [[ $# -eq 0 ]]; then
                echo -e "${RED}Error: Please provide a JSON file.${NC}"
                echo "Usage: mlh json --isvalid [-d|--detail] <file>"
                exit 1
            fi

            # Check if first arg is a flag or a file
            if [[ "$1" != "-d" && "$1" != "--detail" ]]; then
                # No detail flag provided, add it for mlh json
                "$PLUGIN_DIR/isjsonvalid.sh" --detail "$@"
            else
                # User provided detail flag, forward as-is
                "$PLUGIN_DIR/isjsonvalid.sh" "$@"
            fi
            ;;
        get)
            if [[ $# -lt 4 ]] || [[ "$3" != "from" ]]; then
                echo -e "${RED}Error: Invalid syntax.${NC}"
                echo "Usage: mlh json get <field> from <file>"
                exit 1
            fi
            fuzzy_search "$2" "$4"
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$1'${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
