#!/usr/bin/env bash

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# use the root directory
cd "$(dirname "$0")"

zig build generate-website

if [ -x "$(command -v xdg-open)" ]; then
  xdg-open ./www/index.html
elif [ -x "$(command -v open)" ]; then
  open ./www/index.html
fi
