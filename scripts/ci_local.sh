#!/usr/bin/env bash
set -euo pipefail

PROJECT="Axis.xcodeproj"
SCHEME="Axis"
DEST="generic/platform=iOS Simulator"

xcodebuild -resolvePackageDependencies -project "$PROJECT"
xcodebuild -skipMacroValidation -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -destination "$DEST" build
