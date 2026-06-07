#!/bin/sh
set -euo pipefail

PLIST="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Info.plist"
APP_ID="ca-app-pub-8054978526190901~8544964764"

if [ ! -f "${PLIST}" ]; then
  echo "error: App Info.plist not found at ${PLIST}" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Delete :GADApplicationIdentifier" "${PLIST}" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :GADApplicationIdentifier string ${APP_ID}" "${PLIST}"

