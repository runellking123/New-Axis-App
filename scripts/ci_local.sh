#!/usr/bin/env bash
set -euo pipefail

PROJECT="Axis.xcodeproj"
SCHEME="Axis"
DEST="generic/platform=iOS Simulator"

bash "$(dirname "$0")/generate_secrets.sh"
xcodebuild -resolvePackageDependencies -project "$PROJECT"
xcodebuild -skipMacroValidation -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -destination "$DEST" build
