#!/bin/zsh
set -euo pipefail

DEVICE_ID="${HELLOWORLD_DEVICE_ID:-55F9A799-6DA8-59A7-A64E-E78239F84351}"
APP_BUNDLE_ID="${HELLOWORLD_APP_BUNDLE_ID:-Neko.HelloWorld}"

echo "[stream_device_runtime_logs] device=${DEVICE_ID} bundle=${APP_BUNDLE_ID}"
echo "[stream_device_runtime_logs] launching with HELLOWORLD_RUNTIME_LOGGING=1"

xcrun devicectl device process launch \
  --device "${DEVICE_ID}" \
  --terminate-existing \
  --console \
  --environment-variables '{"HELLOWORLD_RUNTIME_LOGGING":"1"}' \
  "${APP_BUNDLE_ID}"
