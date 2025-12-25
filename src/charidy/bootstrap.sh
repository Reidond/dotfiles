#!/usr/bin/env bash
# bootstrap_charidy.sh
# Clones Charidy repos, checks out develop (fallback main/master), runs `mise trust .` + `mise install`,
# installs deps (pnpm/npm/yarn/go) INSIDE `mise exec --` env, creates a VS Code workspace,
# and skips any Node installs in go.charidy.com.
# Usage: ./bootstrap_charidy.sh [workspace-name]   # default: charidy.code-workspace

set -Eeuo pipefail
trap 'echo -e "\033[1;31m[ERR ]\033[0m Failed at line $LINENO: $BASH_COMMAND" >&2' ERR
IFS=$'\n\t'

WORKSPACE_FILE="${1:-charidy.code-workspace}"

REPOS=(
  "git@gitlab.com:charidy/go.charidy.com.git"
  "git@gitlab.com:charidy/dashboard.charidy.com.git"
  "git@gitlab.com:charidy/dashboard-v2.git"
  "git@gitlab.com:charidy/ssr.git"
  "git@gitlab.com:charidy/ssr2.git"
  "git@gitlab.com:charidy/donate.charidy.com.git"
  "git@gitlab.com:charidy/donate2.git"
  "git@gitlab.com:charidy/admin.charidy.com.git"
  "git@gitlab.com:charidy/customview.git"
)

# Install subdir overrides (workspace points to that too)
declare -A INSTALL_SUBDIR
INSTALL_SUBDIR["customview"]="new_team_page"

declare -A WORKSPACE_PATH
WORKSPACE_PATH["customview"]="customview/new_team_page"

# Repos where Node installs must be skipped (even if package.json/lockfiles exist)
declare -A SKIP_NODE_INSTALL
SKIP_NODE_INSTALL["go.charidy.com"]="1"

# --- utils ---
log()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Run commands inside mise env if available; otherwise run directly.
mexec() {
  if command_exists mise; then
    mise exec -- "$@"
  else
    "$@"
  fi
}

repo_dir_from_url() {
  local url="$1"
  local base; base="$(basename "$url")"
  echo "${base%.git}"
}

repo_root_from_path() {
  local path="$1"
  echo "${path%%/*}"
}

ensure_clean_worktree() {
  # Use mise env in case git is managed or PATH is altered
  if [[ -n "$(mexec git status --porcelain)" ]]; then
    err "Uncommitted changes in $(pwd). Please commit/stash/clean before running."
  fi
}

has_mise_config() {
  local dir="$1"
  local files=(".mise.toml" ".mise.yaml" ".mise.yml" "mise.toml" "mise.yaml" "mise.yml")
  for f in "${files[@]}"; do
    [[ -f "$dir/$f" ]] && return 0
  done
  return 1
}

trust_and_install_dir() {
  # Trust + install the toolchain for this directory
  local dir="$1"
  [[ -d "$dir" ]] || err "Directory not found: $dir"

  local cfg_present=false
  if has_mise_config "$dir"; then cfg_present=true; fi

  if command_exists mise; then
    pushd "$dir" >/dev/null
    log "Running: mise trust .  (in $(pwd))"
    # Call mise directly (not via mexec) to avoid any chicken-and-egg issues
    mise trust . >/dev/null
    if [[ "$cfg_present" == true ]]; then
      log "Running: mise install  (in $(pwd))"
      mise install >/dev/null
    else
      warn "No mise config in $(pwd) — skipping 'mise install'."
    fi
    popd >/dev/null
  else
    if [[ "$cfg_present" == true ]]; then
      err "mise config detected in $dir but 'mise' is not installed."
    else
      warn "mise not found; no mise config in $dir — continuing."
    fi
  fi
}

checkout_preferred_branch() {
  local -a preferred=(develop main master)
  mexec git fetch --all --prune --quiet

  local chosen=""
  for br in "${preferred[@]}"; do
    if mexec git ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; then
      chosen="$br"; break
    fi
  done
  [[ -n "$chosen" ]] || err "No develop/main/master found on origin."

  if mexec git show-ref --verify --quiet "refs/heads/$chosen"; then
    mexec git checkout "$chosen" --quiet
  else
    mexec git checkout -b "$chosen" "origin/$chosen" --quiet
  fi

  ensure_clean_worktree
  mexec git pull --ff-only origin "$chosen" --quiet
  echo "$chosen"
}

install_deps_in() {
  local path="$1"
  [[ -d "$path" ]] || err "Install path missing: $path"

  local root; root="$(repo_root_from_path "$path")"
  local skip_node=false
  if [[ -n "${SKIP_NODE_INSTALL[$root]+set}" ]]; then
    skip_node=true
  fi

  # Ensure tools are trusted/installed for this dir
  trust_and_install_dir "$path"
  pushd "$path" >/dev/null

  # Go deps
  if [[ -f go.mod ]]; then
    log "go.mod detected → go mod download"
    mexec go mod download
  fi

  # Node deps (respect skip flag)
  if [[ "$skip_node" == true ]]; then
    if [[ -f package.json || -f pnpm-lock.yaml || -f yarn.lock || -f package-lock.json ]]; then
      log "Skipping Node installs in $root (per SKIP_NODE_INSTALL)."
    fi
  else
    if [[ -f pnpm-lock.yaml ]]; then
      log "pnpm-lock.yaml detected → pnpm install"
      mexec pnpm install --prefer-offline
    elif [[ -f package-lock.json ]]; then
      log "package-lock.json detected → npm ci"
      mexec npm ci
    elif [[ -f yarn.lock ]]; then
      log "yarn.lock detected → yarn install"
      mexec yarn install --frozen-lockfile
    elif [[ -f package.json ]]; then
      log "package.json (no lock) → npm install"
      mexec npm install
    fi
  fi

  popd >/dev/null
}

clone_or_update_repo() {
  local url="$1"
  local dir; dir="$(repo_dir_from_url "$url")"

  if [[ -d "$dir/.git" ]]; then
    log "Updating $dir"
    pushd "$dir" >/dev/null
    trust_and_install_dir "$(pwd)"
    checkout_preferred_branch
    popd >/dev/null
  else
    log "Cloning $url → $dir"
    mexec git clone --quiet "$url" "$dir"
    pushd "$dir" >/dev/null
    trust_and_install_dir "$(pwd)"
    checkout_preferred_branch
    popd >/dev/null
  fi

  # Decide where to install deps (subdir override or root)
  if [[ -n "${INSTALL_SUBDIR[$dir]+set}" ]]; then
    local sub="${INSTALL_SUBDIR[$dir]}"
    [[ -d "$dir/$sub" ]] || err "Expected subdir '$sub' not found in $dir."
    install_deps_in "$dir/$sub"
  else
    install_deps_in "$dir"
  fi
}

create_workspace() {
  local file="$1"
  log "Creating VS Code workspace: $file"
  local entries=()
  for url in "${REPOS[@]}"; do
    local dir; dir="$(repo_dir_from_url "$url")"
    local name="$dir"
    local path="$dir"

    if [[ -n "${WORKSPACE_PATH[$dir]+set}" ]]; then
      path="${WORKSPACE_PATH[$dir]}"
      name="$path"
    fi

    [[ -d "$path" ]] || err "Workspace folder missing: $path (expected after clone/install)."
    entries+=( "{\"name\": \"${name}\", \"path\": \"${path}\"}" )
  done

  {
    printf '{\n  "folders": [\n'
    local first=1
    for e in "${entries[@]}"; do
      if [[ $first -eq 1 ]]; then
        printf "    %s\n" "$e"
        first=0
      else
        printf "    ,%s\n" "$e"
      fi
    done
    printf '  ],\n  "settings": {\n'
    printf '    "files.eol": "\\n",\n'
    printf '    "editor.tabSize": 2,\n'
    printf '    "typescript.tsserver.maxTsServerMemory": 4096,\n'
    printf '    "go.toolsManagement.autoUpdate": true,\n'
    printf '    "terminal.integrated.defaultProfile.linux": "bash"\n'
    printf '  }\n}\n'
  } > "$file"

  log "Workspace written to: $file"
}

# --- main ---
log "Starting bootstrap…"

# FYI only
if command_exists mise; then
  log "Found mise: $(command -v mise)"
else
  warn "mise not found; will run commands directly (ok if no mise configs are present)."
fi

for repo in "${REPOS[@]}"; do
  clone_or_update_repo "$repo"
done

create_workspace "$WORKSPACE_FILE"
log "Done."
