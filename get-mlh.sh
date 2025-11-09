#!/usr/bin/env bash
set -euo pipefail

# ====== Your repo ======
REPO_OWNER="melihcelenk"
REPO_NAME="MyLinuxHelper"
REPO_BRANCH="release/test"
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
			git -C "${INSTALL_DIR}" fetch --all --depth=1
			git -C "${INSTALL_DIR}" checkout "${REPO_BRANCH}"
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
		if [ "$dlr" = "curl" ]; then
			curl -fsSL "${REPO_TARBALL_URL}" | tar -xz -C "${INSTALL_DIR}.tmp"
		else
			wget -qO- "${REPO_TARBALL_URL}" | tar -xz -C "${INSTALL_DIR}.tmp"
		fi
		rm -rf "${INSTALL_DIR}"
		mv "${INSTALL_DIR}.tmp/${REPO_NAME}-${REPO_BRANCH}" "${INSTALL_DIR}"
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
