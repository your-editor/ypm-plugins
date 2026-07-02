#!/usr/bin/env bash

read -e -p "Insert the repo url here (https only):" plugin_url

echo ""
echo "Add the path to where you want it to go."

read -e -p "git submodule add "$plugin_url" " plugin_path

git submodule add $plugin_url $plugin_path

cwd=$(pwd)
# Copy every manpage at the plugin root into man/man7/. The file is named by
# its full path (e.g. lang-syntax-yaml.7), not by the basename, so glob all
# *.7 rather than guessing the name.
shopt -s nullglob
mans=("$plugin_path"/*.7)
shopt -u nullglob
if [ ${#mans[@]} -gt 0 ]; then
    cp "${mans[@]}" "${cwd}/man/man7/"
    echo "Copied ${#mans[@]} manpage(s) to man/man7/"
else
    echo "No *.7 manpage found in $plugin_path (nothing copied)."
fi
