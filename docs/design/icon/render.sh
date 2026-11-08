#!/bin/zsh
# Renders the app icon SVGs in this folder into App/Assets.xcassets/AppIcon.appiconset with headless Chrome.
# appicon-small.svg (no text lines, larger page and check) serves the 16 pt and 32 pt slots; appicon.svg the rest.
# Run from the repository root: docs/design/icon/render.sh
set -euo pipefail

chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
source_dir="${0:A:h}"
iconset="App/Assets.xcassets/AppIcon.appiconset"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

render() {
  local svg="$1" pixels="$2" png="$3"
  print -r -- "<!doctype html><html><body style=\"margin:0;background:transparent\"><img src=\"file://$source_dir/$svg\" width=\"$pixels\" height=\"$pixels\" style=\"display:block\"></body></html>" >"$work_dir/page.html"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --default-background-color=00000000 --force-device-scale-factor=1 --window-size="$pixels,$pixels" \
    --screenshot="$iconset/$png" "file://$work_dir/page.html" >/dev/null 2>&1
}

render appicon-small.svg 16 icon_16x16.png
render appicon-small.svg 32 icon_16x16@2x.png
render appicon-small.svg 32 icon_32x32.png
render appicon-small.svg 64 icon_32x32@2x.png
render appicon.svg 128 icon_128x128.png
render appicon.svg 256 icon_128x128@2x.png
render appicon.svg 256 icon_256x256.png
render appicon.svg 512 icon_256x256@2x.png
render appicon.svg 512 icon_512x512.png
render appicon.svg 1024 icon_512x512@2x.png
