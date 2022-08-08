#!/usr/bin/env bash

read -e -p "git submodule update --init --remote --merge " plugin_name
git submodule init $plugin_name
git submodule update $plugin_name
cwd=$(pwd)
cd $plugin_name
git checkout main
git pull
cd $cwd
cp $plugin_name*.7 man/man7/
