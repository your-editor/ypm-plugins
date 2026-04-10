#!/usr/bin/env bash

read -e -p "Insert the repo url here (https only):" plugin_url

echo ""
echo "Add the path to where you want it to go."

read -e -p "git submodule add "$plugin_url" " plugin_path

git submodule add $plugin_url $plugin_path

cwd=$(pwd)
cd $plugin_path
cp $(basename ${plugin_path})*.7 ${cwd}/man/man7/ 2>/dev/null
