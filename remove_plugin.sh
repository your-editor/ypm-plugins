#!/usr/bin/env bash

if [[ $# == "0" ]]; then
    read -e -p "Directory to plugin you want to remove:" plugin_name
else
    plugin_name=$1
fi

plugin_name="${plugin_name%/}"

if [ ! -d "$plugin_name" ]; then
    echo "Not a directory: $plugin_name"
    exit 1
fi

# Make sure the submodule is populated so we can find its manpages
if [ -z "$(ls -A "$plugin_name" 2>/dev/null)" ]; then
    git submodule update --init "$plugin_name"
fi

cwd=$(pwd)

manpages=()
for src in "$plugin_name"/*.7; do
    [ -f "$src" ] || continue
    fname=$(basename "$src")
    if [ -f "${cwd}/man/man7/$fname" ]; then
        manpages+=("${cwd}/man/man7/$fname")
    fi
done

echo ""
echo "Will remove plugin: $plugin_name"
if [ ${#manpages[@]} -gt 0 ]; then
    echo "Will remove manpages:"
    for m in "${manpages[@]}"; do
        echo "  ${m#${cwd}/}"
    done
fi
read -e -p "Proceed? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

git submodule deinit -f -- "$plugin_name"
rm -rf ".git/modules/$plugin_name"
git rm -f "$plugin_name"

for m in "${manpages[@]}"; do
    rm -f "$m"
done

echo ""
echo "Removed $plugin_name"
