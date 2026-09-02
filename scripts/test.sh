#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_cache="${TMPDIR:-/private/tmp}/resize-tests"
mkdir -p "$task_cache"
export CLANG_MODULE_CACHE_PATH="$task_cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$task_cache/swift"
swift test --disable-sandbox --scratch-path "$task_cache/build"
