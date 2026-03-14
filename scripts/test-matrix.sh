#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/HelloWorld.xcodeproj"
SCHEME="HelloWorld"
DERIVED_DATA="$REPO_ROOT/.DerivedData"
DESTINATIONS=(
  "iPhone 12 mini"
)

available_devices="$(xcrun simctl list devices available)"

for device_name in "${DESTINATIONS[@]}"; do
  uuid="$(
    print -r -- "$available_devices" \
      | sed -nE "s/^[[:space:]]+${device_name// /[[:space:]]+} \\(([A-F0-9-]+)\\).*/\\1/p" \
      | head -n 1
  )"

  if [[ -z "$uuid" ]]; then
    echo "Skipping ${device_name}: simulator not installed"
    continue
  fi

  echo "Running tests on ${device_name} (${uuid})"
  xcrun simctl bootstatus "$uuid" -b >/dev/null 2>&1 || xcrun simctl boot "$uuid"
  xcrun simctl bootstatus "$uuid" -b

  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=${uuid}" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
done
