#!/usr/bin/env bash

read -e -p "git submodule update --init --remote --merge " plugin_name
git submodule update --init --remote --merge $plugin_name
