#!/usr/bin/env bash

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# use the root directory
cd "$(dirname "$0")"

zig build generate-website

simple-http-server --open --ip 127.0.0.1 --port 8007 --index -- ./www/
