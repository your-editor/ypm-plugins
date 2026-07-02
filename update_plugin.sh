#!/usr/bin/env bash

if [[ $# == "0" ]]; then
    read -e -p "Directory to plugin you want to update:" plugin_name
else
    plugin_name=$1
fi

git submodule init $plugin_name
git submodule update $plugin_name
cwd=$(pwd)
cd $plugin_name
git checkout main || git checkout master
git pull
cd "$cwd"
# Copy every manpage at the plugin root (named by full path, e.g.
# lang-syntax-yaml.7), not just one matching the basename.
shopt -s nullglob
mans=("$plugin_name"/*.7)
shopt -u nullglob
if [ ${#mans[@]} -gt 0 ]; then
    cp "${mans[@]}" "${cwd}/man/man7/"
    echo "Copied ${#mans[@]} manpage(s) to man/man7/"
else
    echo "No *.7 manpage found in $plugin_name (nothing copied)."
fi
