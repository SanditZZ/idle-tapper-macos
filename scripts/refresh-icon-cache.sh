#!/usr/bin/env bash
#
# refresh-icon-cache.sh — make macOS notice a changed app icon.
#
# macOS caches an app's icon against its bundle in the Launch Services
# database. A development build keeps the same bundle path across rebuilds, so
# once a stale icon is cached — most commonly the placeholder grid recorded
# before the icon set existed — Finder, the Dock and Spotlight keep showing it
# no matter how many times the app is rebuilt.
#
# The bundle itself is fine in that situation; only the cache is wrong. This
# re-registers the bundle and restarts the Dock so the new icon is picked up.
#
# Run it after `swift scripts/generate-app-icon.swift`, or any time the icon on
# screen disagrees with the icon in the asset catalog.
#
# Usage:
#   scripts/refresh-icon-cache.sh              # the Debug build in DerivedData
#   scripts/refresh-icon-cache.sh /path/to/App.app

set -euo pipefail

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

APP_PATH="${1:-}"

if [ -z "${APP_PATH}" ]; then
    # Resolve the most recently built Debug app for this project.
    APP_PATH="$(find "${HOME}/Library/Developer/Xcode/DerivedData" \
        -maxdepth 5 -name "IdleTapper.app" -path "*/Build/Products/Debug/*" \
        2>/dev/null | head -1)"
fi

if [ -z "${APP_PATH}" ] || [ ! -d "${APP_PATH}" ]; then
    echo "No app bundle found. Build first, or pass the path explicitly." >&2
    exit 1
fi

if [ ! -x "${LSREGISTER}" ]; then
    echo "lsregister not found at the expected path — macOS may have moved it." >&2
    exit 1
fi

echo "==> Refreshing icon cache for ${APP_PATH}"

# Bumping the modification time is what invalidates the cached entry; the
# re-registration alone is sometimes ignored for an unchanged bundle.
touch "${APP_PATH}"
"${LSREGISTER}" -f "${APP_PATH}"

# The Dock holds its own copy of the icon. Restarting it is harmless — it
# relaunches immediately and nothing is lost.
killall Dock 2>/dev/null || true

echo "==> Done. Finder, the Dock and Spotlight should now show the current icon."
echo "    If Spotlight still disagrees, give its index a few seconds to catch up."
