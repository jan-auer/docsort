#!/bin/bash
# Builds Docsort in the Release configuration and installs it to /Applications.
#
# Usage: scripts/install.sh [--no-open]
#   --no-open  install without launching the installed app afterwards
set -euo pipefail

usage="Usage: scripts/install.sh [--no-open]"
launch_after_install=yes
for argument in "$@"; do
  case "$argument" in
    --no-open) launch_after_install=no ;;
    -h | --help)
      echo "$usage"
      exit 0
      ;;
    *)
      echo "$usage" >&2
      exit 64
      ;;
  esac
done

cd "$(dirname "$0")/.."

derived_data=.build/xcode
built_app="$derived_data/Build/Products/Release/Docsort.app"
installed_app=/Applications/Docsort.app

# Replacing the bundle under a running app would leave it running old code from deleted files.
if pgrep -f "^$installed_app/Contents/MacOS/Docsort" >/dev/null; then
  echo "Docsort is running from $installed_app. Quit it, then run this script again." >&2
  exit 1
fi

echo "Building Docsort (Release) into $derived_data …"
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' \
  -configuration Release -derivedDataPath "$derived_data" -quiet build

# Remove the old copy first: ditto onto an existing bundle merges, keeping files the new build no longer has.
echo "Installing to $installed_app …"
rm -rf "$installed_app"
ditto "$built_app" "$installed_app"

if [[ "$launch_after_install" == yes ]]; then
  open "$installed_app"
fi
echo "Installed $installed_app."
