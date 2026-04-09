#!/usr/bin/env bash
#
# clean_builds.sh — Remove test_builds artifacts and built plugin files.
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/.test_builds"
PLUGINS_DIR="$SCRIPT_DIR/ypm_plugins"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

echo ""

# Remove the yed build directory
if [ -d "$WORK_DIR" ]; then
    echo -e "  ${RED}removing${RESET} .test_builds/"
    rm -rf "$WORK_DIR"
else
    echo -e "  ${DIM}.test_builds/ not found${RESET}"
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

# Reset submodules to clean state
echo -e "  ${DIM}resetting submodules...${RESET}"
cd "$SCRIPT_DIR"
git submodule deinit -f --all 2>/dev/null
git checkout -- ypm_plugins/ 2>/dev/null

echo ""
echo -e "  ${GREEN}clean${RESET}"
echo ""
