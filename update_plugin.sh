#!/usr/bin/env bash

read -e -p "Directory to plugin you want to update:" plugin_name
git submodule init $plugin_name
git submodule update $plugin_name
cwd=$(pwd)
cd $plugin_name
git checkout main || git checkout master
git pull
cp $(basename ${plugin_name})*.7 ${cwd}/man/man7/
