#!/usr/bin/env bash
set -euo pipefail

# ====== Your repo ======
REPO_OWNER="melihcelenk"
REPO_NAME="MyLinuxHelper"
REPO_BRANCH="bug/bookmark-list-category-hierarchy"
# =======================

REPO_TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REPO_BRANCH}"
REPO_GIT_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

INSTALL_DIR="${HOME}/.mylinuxhelper"
LOCAL_BIN="${HOME}/.local/bin"
BASHRC="${HOME}/.bashrc"
PROFILE="${HOME}/.profile"

green() { printf "\033[1;32m%s\033[0m\n" "$*"; }

ensure_downloader() {
	if command -v curl >/dev/null 2>&1; then
		echo curl
		return
	fi
	if command -v wget >/dev/null 2>&1; then
		echo wget
		return
	fi

	echo "No curl/wget found. Trying to install curl..."
	if command -v apt >/dev/null 2>&1; then
		sudo apt update -y && sudo apt install -y curl
	elif command -v apt-get >/dev/null 2>&1; then
		sudo apt-get update -y && sudo apt-get install -y curl
	elif command -v dnf >/dev/null 2>&1; then
		sudo dnf install -y curl
	elif command -v yum >/dev/null 2>&1; then
		sudo yum install -y curl
	elif command -v zypper >/dev/null 2>&1; then
		sudo zypper install -y curl
	elif command -v pacman >/dev/null 2>&1; then
		sudo pacman -Sy --noconfirm curl
	elif command -v apk >/dev/null 2>&1; then
		sudo apk add curl
	else
		echo "Error: no downloader and no supported package manager. Install curl or wget manually."
		exit 1
	fi

	command -v curl >/dev/null 2>&1 && {
		echo curl
		return
	}
	command -v wget >/dev/null 2>&1 && {
		echo wget
		return
	}
	echo "Error: failed to install a downloader."
	exit 1
}

download_repo() {
	mkdir -p "${INSTALL_DIR}"
	if command -v git >/dev/null 2>&1; then
		if [ -d "${INSTALL_DIR}/.git" ]; then
			green "Updating repo (git pull)…"
			# Fetch all branches including remote branches with slashes
			git -C "${INSTALL_DIR}" fetch origin --depth=1
			# Check if branch exists locally, if not create tracking branch
			if ! git -C "${INSTALL_DIR}" rev-parse --verify "${REPO_BRANCH}" >/dev/null 2>&1; then
				# Branch doesn't exist locally, create tracking branch
				git -C "${INSTALL_DIR}" checkout -b "${REPO_BRANCH}" "origin/${REPO_BRANCH}" 2>/dev/null || \
				git -C "${INSTALL_DIR}" checkout "${REPO_BRANCH}" 2>/dev/null || \
				git -C "${INSTALL_DIR}" checkout -b "${REPO_BRANCH}" "origin/${REPO_BRANCH}"
			else
				# Branch exists locally, switch to it
				git -C "${INSTALL_DIR}" checkout "${REPO_BRANCH}"
			fi
			# Reset to remote branch
			git -C "${INSTALL_DIR}" reset --hard "origin/${REPO_BRANCH}"
		else
			green "Cloning repo (git)…"
			git clone --depth=1 --branch "${REPO_BRANCH}" "${REPO_GIT_URL}" "${INSTALL_DIR}"
		fi
	else
		green "Downloading repo (tarball)…"
		rm -rf "${INSTALL_DIR}.tmp"
		mkdir -p "${INSTALL_DIR}.tmp"
		local dlr
		dlr="$(ensure_downloader)"
		# GitHub tarball URLs with branch names containing slashes need URL encoding
		# Replace / with %2F in branch name for tarball URL
		local encoded_branch
		encoded_branch=$(echo "${REPO_BRANCH}" | sed 's|/|%2F|g')
		local tarball_url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${encoded_branch}"
		if [ "$dlr" = "curl" ]; then
			curl -fsSL "${tarball_url}" | tar -xz -C "${INSTALL_DIR}.tmp"
		else
			wget -qO- "${tarball_url}" | tar -xz -C "${INSTALL_DIR}.tmp"
		fi
		rm -rf "${INSTALL_DIR}"
		# Tarball extracts to directory with branch name (slashes replaced with dashes in some cases, or URL encoded)
		# Try different possible directory names
		if [ -d "${INSTALL_DIR}.tmp/${REPO_NAME}-${REPO_BRANCH}" ]; then
			mv "${INSTALL_DIR}.tmp/${REPO_NAME}-${REPO_BRANCH}" "${INSTALL_DIR}"
		elif [ -d "${INSTALL_DIR}.tmp/${REPO_NAME}-$(echo "${REPO_BRANCH}" | sed 's|/|-|g')" ]; then
			mv "${INSTALL_DIR}.tmp/${REPO_NAME}-$(echo "${REPO_BRANCH}" | sed 's|/|-|g')" "${INSTALL_DIR}"
		else
			# Find the extracted directory
			local extracted_dir
			extracted_dir=$(find "${INSTALL_DIR}.tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
			if [ -n "$extracted_dir" ]; then
				mv "$extracted_dir" "${INSTALL_DIR}"
			else
				echo "Error: Could not find extracted directory"
				exit 1
			fi
		fi
		rm -rf "${INSTALL_DIR}.tmp"
	fi
}

ensure_local_bin_on_path() {
	mkdir -p "${LOCAL_BIN}"
	# shellcheck disable=SC2016
	local line='export PATH="$HOME/.local/bin:$PATH"'
	grep -Fq "$line" "$BASHRC" 2>/dev/null || echo "$line" >>"$BASHRC"
	grep -Fq "$line" "$PROFILE" 2>/dev/null || echo "$line" >>"$PROFILE"
}

cleanup_unnecessary_files() {
	green "Cleaning up unnecessary files…"

	# List of files/directories to remove (user doesn't need these)
	# NOTE: .git is NOT removed - it's needed for git pull/update functionality
	local cleanup_items=(
		"tests"
		"CLAUDE.md"
		"docs/BOOKMARK_ALIAS_GUIDE.md"
		"docs/BOOKMARK_QUICK_REFERENCE.md"
		"docs/RELEASE_NOTES_v1.5.0.md"
		"docs/RELEASE_NOTES_v1.5.1.md"
		"docs/assets"
		".github"
		"TODO.md"
		".gitignore"
	)

	# Keep docs/config/mlh.conf.example (needed for setup.sh)
	# Keep README.md (useful for users)
	# Keep LICENSE (required)
	# Keep .git (needed for git pull/update functionality)

	for item in "${cleanup_items[@]}"; do
		local item_path="${INSTALL_DIR}/${item}"
		if [ -e "$item_path" ]; then
			rm -rf "$item_path"
			echo "  Removed: $item"
		fi
	done

	# Clean up docs directory if it's now empty (except config/)
	if [ -d "${INSTALL_DIR}/docs" ]; then
		# Check if docs only contains config/ directory
		local docs_contents
		docs_contents=$(find "${INSTALL_DIR}/docs" -mindepth 1 -maxdepth 1 ! -name "config" | wc -l)
		if [ "$docs_contents" -eq 0 ]; then
			# Keep docs/config, but we can leave docs/ as is since it only has config/
			:
		fi
	fi
}

run_repo_setup() {
	green "Running repository setup…"
	chmod +x "${INSTALL_DIR}/setup.sh" || true
	bash "${INSTALL_DIR}/setup.sh"
}

main() {
	green "Installing ${REPO_NAME} into ${INSTALL_DIR}"
	download_repo
	# Cleanup unnecessary files (both git and tarball methods include development files)
	cleanup_unnecessary_files
	ensure_local_bin_on_path
	run_repo_setup
	green "Done. Try:"
	echo "  i --help"
	echo "  isjsonvalid --help"
	echo "  ll /etc"
}
main "$@"
