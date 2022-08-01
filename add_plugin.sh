#!/usr/bin/env bash

read -e -p "Insert the repo url here (https only):" plugin_url

echo ""
echo "Add the path to where you want it to go."

read -e -p "git submodule add "$plugin_url" " plugin_path

git submodule add $plugin_url $plugin_path
