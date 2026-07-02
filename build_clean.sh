#!/usr/bin/env bash
#
# build_clean.sh — Remove build_check artifacts and built plugin files.
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/.build_check"
PLUGINS_DIR="$SCRIPT_DIR/ypm_plugins"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

echo ""

# Remove the yed build directory
if [ -d "$WORK_DIR" ]; then
    echo -e "  ${RED}removing${RESET} .build_check/"
    rm -rf "$WORK_DIR"
else
    echo -e "  ${DIM}.build_check/ not found${RESET}"
fi

# Remove .so files from plugin directories
count=0
while IFS= read -r -d '' so_file; do
    echo -e "  ${RED}removing${RESET} ${so_file#$SCRIPT_DIR/}"
    rm -f "$so_file"
    ((count++))
done < <(find "$PLUGINS_DIR" -name "*.so" -print0 2>/dev/null)

if [ "$count" -eq 0 ]; then
    echo -e "  ${DIM}no .so files found${RESET}"
fi

# NOTE: we intentionally do NOT touch git state here (no `submodule deinit`,
# no `git checkout -- ypm_plugins/`). Those revert submodule pointers and wipe
# working trees, discarding intentional, uncommitted changes. Cleaning only
# removes build artifacts; anything git-tracked is left alone.

echo ""
echo -e "  ${GREEN}clean${RESET}"
echo ""
