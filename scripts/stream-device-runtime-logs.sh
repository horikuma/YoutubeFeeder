#!/bin/zsh
set -euo pipefail

DEVICE_ID="${YOUTUBEFEEDER_DEVICE_ID:-55F9A799-6DA8-59A7-A64E-E78239F84351}"
APP_BUNDLE_ID="${YOUTUBEFEEDER_APP_BUNDLE_ID:-Neko.YoutubeFeeder}"

echo "[stream-device-runtime-logs] device=${DEVICE_ID} bundle=${APP_BUNDLE_ID}"
echo "[stream-device-runtime-logs] launching with YOUTUBEFEEDER_RUNTIME_LOGGING=1"

xcrun devicectl device process launch \
  --device "${DEVICE_ID}" \
  --terminate-existing \
  --console \
  --environment-variables '{"YOUTUBEFEEDER_RUNTIME_LOGGING":"1"}' \
  "${APP_BUNDLE_ID}"
