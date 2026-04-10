#!/usr/bin/env bash
#
# build_check.sh — Build-test all ypm plugins against a yed version.
#
# Usage:
#   ./build_check.sh [branch]
#
# Examples:
#   ./build_check.sh              # defaults to dev
#   ./build_check.sh master       # yed master + ypm v1600
#   ./build_check.sh dev          # yed dev + ypm v1700
#
# The script will:
#   1. Clone and build yed locally (into .build_check/yed)
#   2. Checkout the matching ypm-plugins branch
#   3. Init/update all submodules
#   4. Try to build each plugin using that yed
#   5. Print a colored summary

set -uo pipefail

# ── Branch mapping ──────────────────────────────────────
# yed branch → ypm-plugins branch
declare -A BRANCH_MAP=(
    ["master"]="v1600"
    ["dev"]="v1700"
)

INPUT="${1:-}"

if [ -n "$INPUT" ]; then
    YED_BRANCH="$INPUT"
    YPM_BRANCH="${BRANCH_MAP[$INPUT]:-}"
    if [ -z "$YPM_BRANCH" ]; then
        echo "Unknown branch: $INPUT"
        echo "Known branches: ${!BRANCH_MAP[*]}"
        exit 1
    fi
else
    # Default to dev
    YED_BRANCH="dev"
    YPM_BRANCH="${BRANCH_MAP[dev]}"
fi
YED_REPO="https://github.com/kammerdienerb/yed.git"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/.build_check"
YED_DIR="$WORK_DIR/yed"
YED_INSTALL="$WORK_DIR/yed_install"
PLUGINS_DIR="$SCRIPT_DIR/ypm_plugins"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Counters ────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0
DONE=0
TOTAL=0
declare -a FAILED_PLUGINS=()
declare -a SKIPPED_PLUGINS=()

# ── Helper ──────────────────────────────────────────────
log()  { echo -e "${CYAN}::${RESET} $*"; }

progress_bar() {
    ((DONE++))
    local pct=$((DONE * 100 / TOTAL))
    local filled=$((pct / 2))
    local empty=$((50 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    local pad=""
    for ((i=0; i<empty; i++)); do pad+="░"; done
    echo -ne "\r  [${GREEN}${bar}${DIM}${pad}${RESET}] ${pct}% (${DONE}/${TOTAL})" >&2
}

clear_line() { echo -ne "\r\033[K" >&2; }

pass() { clear_line; echo -e "  ${GREEN}✓${RESET} $1"; ((PASS++)); progress_bar; }
fail() { clear_line; echo -e "  ${RED}✗${RESET} $1 ${DIM}— $2${RESET}"; ((FAIL++)); FAILED_PLUGINS+=("$1"); progress_bar; }
skip() { clear_line; echo -e "  ${YELLOW}–${RESET} $1 ${DIM}($2)${RESET}"; ((SKIP++)); SKIPPED_PLUGINS+=("$1"); progress_bar; }

# ── Step 1: Clone/update and build yed ──────────────────
build_yed() {
    log "Building yed (branch: ${BOLD}$YED_BRANCH${RESET})"

    mkdir -p "$WORK_DIR"

    if [ -d "$YED_DIR" ]; then
        cd "$YED_DIR"
        git fetch origin
        git checkout "$YED_BRANCH"
        git pull origin "$YED_BRANCH"
    else
        git clone "$YED_REPO" "$YED_DIR"
        cd "$YED_DIR"
        git checkout "$YED_BRANCH"
    fi

    rm -rf "$YED_INSTALL"
    mkdir -p "$YED_INSTALL"

    ./install.sh -p "$YED_INSTALL" 2>&1 | tail -3

    cd "$SCRIPT_DIR"

    # Verify yed binary exists
    if [ ! -f "$YED_INSTALL/bin/yed" ]; then
        echo -e "${RED}ERROR: yed failed to build.${RESET}"
        exit 1
    fi

    export PATH="$YED_INSTALL/bin:$PATH"
    log "yed installed to $YED_INSTALL/bin/yed"
    echo ""
}

# ── Step 2: Checkout ypm-plugins branch ─────────────────
checkout_ypm() {
    cd "$SCRIPT_DIR"

    log "Checking out ypm-plugins branch: ${BOLD}$YPM_BRANCH${RESET}"
    git checkout "$YPM_BRANCH"

    log "Initializing submodules..."
    git submodule update --init --recursive 2>&1 | tail -5
    echo ""
}

# ── Step 3: Build each plugin ───────────────────────────
build_plugin() {
    local name="$1"
    local dir="$2"

    cd "$dir"

    # Check if submodule is populated
    if [ ! -f "build.sh" ] && [ ! -f "Makefile" ]; then
        # Check for any .c files we could try to compile
        local c_files
        c_files=$(find . -maxdepth 1 -name "*.c" 2>/dev/null)
        if [ -z "$c_files" ]; then
            skip "$name" "no source files"
            return
        fi
        # Try a generic compile
        local output so_name
        so_name="${name##*/}.so"
        output=$(gcc -o "$so_name" $c_files $(yed --print-cflags) $(yed --print-ldflags) 2>&1) && {
            rm -f "$so_name"
            pass "$name"
        } || {
            fail "$name" "compile error"
        }
        return
    fi

    # Prefer build.sh, fall back to Makefile
    local output
    if [ -f "build.sh" ]; then
        output=$(bash build.sh 2>&1) && {
            pass "$name"
        } || {
            fail "$name" "build.sh failed"
        }
    elif [ -f "Makefile" ]; then
        output=$(make 2>&1) && {
            pass "$name"
        } || {
            fail "$name" "make failed"
        }
    fi
}

count_plugins() {
    local count=0
    for d in "$PLUGINS_DIR"/*/; do
        [ -d "$d" ] || continue
        local n="$(basename "$d")"
        [ "$n" = "lang" ] || [ "$n" = "styles" ] && continue
        ((count++))
    done
    for d in "$PLUGINS_DIR"/lang/*/; do
        [ -d "$d" ] || continue
        local n="$(basename "$d")"
        # lang/syntax and lang/tools contain nested plugins — count their children
        if [ "$n" = "syntax" ] || [ "$n" = "tools" ]; then
            for nested in "$d"*/; do
                [ -d "$nested" ] || continue
                ((count++))
            done
        else
            ((count++))
        fi
    done
    for d in "$PLUGINS_DIR"/styles/*/; do
        [ -d "$d" ] || continue
        ((count++))
    done
    echo "$count"
}

build_all_plugins() {
    TOTAL=$(count_plugins)
    log "Building ${BOLD}$TOTAL${RESET} plugins..."
    echo -e "  ${DIM}yed: $YED_BRANCH | ypm-plugins: $YPM_BRANCH${RESET}"
    echo ""

    # Top-level plugins (skip lang/ and styles/ — they contain nested plugins)
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [ -d "$plugin_dir" ] || continue
        local name
        name="$(basename "$plugin_dir")"
        # Skip parent directories that contain nested plugins
        if [ "$name" = "lang" ] || [ "$name" = "styles" ]; then
            continue
        fi
        build_plugin "$name" "$plugin_dir"
    done

    # Nested plugins (lang/*, styles/*)
    for subdir in "$PLUGINS_DIR"/lang/*/; do
        [ -d "$subdir" ] || continue
        local base
        base="$(basename "$subdir")"
        # lang/syntax and lang/tools contain nested plugins — descend one more level
        if [ "$base" = "syntax" ] || [ "$base" = "tools" ]; then
            for nested in "$subdir"*/; do
                [ -d "$nested" ] || continue
                local name="lang/$base/$(basename "$nested")"
                build_plugin "$name" "$nested"
            done
        else
            build_plugin "lang/$base" "$subdir"
        fi
    done
    for subdir in "$PLUGINS_DIR"/styles/*/; do
        [ -d "$subdir" ] || continue
        build_plugin "styles/$(basename "$subdir")" "$subdir"
    done

    # Clear the progress bar
    clear_line
}

# ── Step 4: Summary ─────────────────────────────────────
print_summary() {
    local TOTAL=$((PASS + FAIL + SKIP))

    echo ""
    echo -e "${BOLD}════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  Build Summary${RESET}"
    echo -e "${BOLD}════════════════════════════════════════${RESET}"
    echo -e "  yed branch:         ${CYAN}$YED_BRANCH${RESET}"
    echo -e "  ypm-plugins branch: ${CYAN}$YPM_BRANCH${RESET}"
    echo -e "  total plugins:      $TOTAL"
    echo -e "  ${GREEN}passed:  $PASS${RESET}"
    echo -e "  ${RED}failed:  $FAIL${RESET}"
    echo -e "  ${YELLOW}skipped: $SKIP${RESET}"
    echo -e "${BOLD}════════════════════════════════════════${RESET}"

    if [ ${#FAILED_PLUGINS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}Failed plugins:${RESET}"
        for p in "${FAILED_PLUGINS[@]}"; do
            echo -e "  ${RED}✗${RESET} $p"
        done
    fi

    if [ ${#SKIPPED_PLUGINS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}Skipped plugins:${RESET}"
        for p in "${SKIPPED_PLUGINS[@]}"; do
            echo -e "  ${YELLOW}–${RESET} $p"
        done
    fi

    echo ""

    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
}

# ── Main ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ypm plugin build tester${RESET}"
echo ""

build_yed
checkout_ypm
build_all_plugins
print_summary
