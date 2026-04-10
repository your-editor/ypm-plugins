#!/usr/bin/env bash
#
# manpage_check.sh — Verify man/man7/ copies are in sync with plugin sources.
#
# Usage:
#   ./manpage_check.sh
#
# For every plugin, scans *.7 files at the plugin root and compares them
# against the corresponding file in man/man7/. Reports outdated, missing,
# and orphaned manpages.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/ypm_plugins"
MAN_DIR="$SCRIPT_DIR/man/man7"

# Manpages in man/man7/ that intentionally have no plugin source
# (e.g. ypm itself is not a plugin in this repo).
ORPHAN_WHITELIST=(
    "ypm.7"
)

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Counters ────────────────────────────────────────────
OK=0
OUTDATED=0
MISSING=0
NONE=0
DONE=0
TOTAL=0
declare -a OUTDATED_LIST=()
declare -a MISSING_LIST=()
declare -a NONE_LIST=()
declare -A CLAIMED

log() { echo -e "${CYAN}::${RESET} $*"; }

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

ensure_submodules() {
    cd "$SCRIPT_DIR"
    # git submodule status prefixes uninitialized entries with '-'.
    # Capture first to avoid SIGPIPE/pipefail interaction with `grep -q`.
    local status
    status=$(git submodule status --recursive 2>/dev/null || true)
    if grep -q '^-' <<< "$status"; then
        log "Initializing submodules..."
        git submodule update --init --recursive 2>&1 | tail -5
        echo ""
    fi
}

count_plugins() {
    local count=0
    for d in "$PLUGINS_DIR"/*/; do
        [ -d "$d" ] || continue
        local n
        n="$(basename "$d")"
        [ "$n" = "lang" ] || [ "$n" = "styles" ] && continue
        ((count++))
    done
    for d in "$PLUGINS_DIR"/lang/*/; do
        [ -d "$d" ] || continue
        local n
        n="$(basename "$d")"
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

check_plugin() {
    local name="$1"
    local dir="$2"

    local -a files=()
    shopt -s nullglob
    for src in "$dir"/*.7; do
        files+=("$src")
    done
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        clear_line
        echo -e "  ${DIM}–${RESET} $name ${DIM}(no manpage)${RESET}"
        ((NONE++))
        NONE_LIST+=("$name")
        progress_bar
        return
    fi

    for src in "${files[@]}"; do
        local fname
        fname="$(basename "$src")"
        CLAIMED["$fname"]=1
        local dest="$MAN_DIR/$fname"
        local label
        if [ ${#files[@]} -eq 1 ]; then
            label="$name"
        else
            label="$name/$fname"
        fi
        clear_line
        if [ ! -f "$dest" ]; then
            echo -e "  ${RED}✗${RESET} $label ${DIM}— missing${RESET}"
            MISSING_LIST+=("$name/$fname")
            ((MISSING++))
        elif ! cmp -s "$src" "$dest"; then
            echo -e "  ${YELLOW}!${RESET} $label ${DIM}— outdated${RESET}"
            OUTDATED_LIST+=("$name/$fname")
            ((OUTDATED++))
        else
            echo -e "  ${GREEN}✓${RESET} $label"
            ((OK++))
        fi
    done

    progress_bar
}

# ── Main ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ypm manpage check${RESET}"
echo ""

ensure_submodules

TOTAL=$(count_plugins)
log "Checking ${BOLD}$TOTAL${RESET} plugins against ${BOLD}man/man7${RESET}"
echo ""

for plugin_dir in "$PLUGINS_DIR"/*/; do
    [ -d "$plugin_dir" ] || continue
    name="$(basename "$plugin_dir")"
    if [ "$name" = "lang" ] || [ "$name" = "styles" ]; then
        continue
    fi
    check_plugin "$name" "$plugin_dir"
done

for subdir in "$PLUGINS_DIR"/lang/*/; do
    [ -d "$subdir" ] || continue
    base="$(basename "$subdir")"
    if [ "$base" = "syntax" ] || [ "$base" = "tools" ]; then
        for nested in "$subdir"*/; do
            [ -d "$nested" ] || continue
            check_plugin "lang/$base/$(basename "$nested")" "$nested"
        done
    else
        check_plugin "lang/$base" "$subdir"
    fi
done

for subdir in "$PLUGINS_DIR"/styles/*/; do
    [ -d "$subdir" ] || continue
    check_plugin "styles/$(basename "$subdir")" "$subdir"
done

clear_line

# ── Orphan detection ────────────────────────────────────
declare -a ORPHAN_LIST=()
ORPHAN=0
declare -A WHITELIST_MAP
for w in "${ORPHAN_WHITELIST[@]}"; do
    WHITELIST_MAP["$w"]=1
done
if [ -d "$MAN_DIR" ]; then
    shopt -s nullglob
    for f in "$MAN_DIR"/*.7; do
        fname="$(basename "$f")"
        if [ -z "${CLAIMED[$fname]:-}" ] && [ -z "${WHITELIST_MAP[$fname]:-}" ]; then
            ORPHAN_LIST+=("$fname")
            ((ORPHAN++))
        fi
    done
    shopt -u nullglob
fi

# ── Summary ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Manpage Summary${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "  total plugins:  $TOTAL"
echo -e "  ${GREEN}up to date:     $OK${RESET}"
echo -e "  ${YELLOW}outdated:       $OUTDATED${RESET}"
echo -e "  ${RED}missing:        $MISSING${RESET}"
echo -e "  ${DIM}no manpage:     $NONE${RESET}"
echo -e "  ${CYAN}orphaned:       $ORPHAN${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"

if [ ${#OUTDATED_LIST[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Outdated:${RESET}"
    for p in "${OUTDATED_LIST[@]}"; do
        echo -e "  ${YELLOW}!${RESET} $p"
    done
fi

if [ ${#MISSING_LIST[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}${BOLD}Missing:${RESET}"
    for p in "${MISSING_LIST[@]}"; do
        echo -e "  ${RED}✗${RESET} $p"
    done
fi

if [ ${#ORPHAN_LIST[@]} -gt 0 ]; then
    echo ""
    echo -e "${CYAN}${BOLD}Orphaned (in man/man7/ but no plugin owns them):${RESET}"
    for p in "${ORPHAN_LIST[@]}"; do
        echo -e "  ${CYAN}?${RESET} $p"
    done
fi

echo ""

if [ "$MISSING" -gt 0 ] || [ "$OUTDATED" -gt 0 ]; then
    exit 1
fi
