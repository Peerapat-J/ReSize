#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project ReSize.xcodeproj -scheme ReSize \
  -configuration Debug -derivedDataPath build/DerivedData build
printf '\nApp: %s/build/DerivedData/Build/Products/Debug/ReSize.app\n' "$PWD"
