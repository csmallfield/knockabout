#!/usr/bin/env bash
# Link the Godot Motion Kit into addons/ (the puppets use its 2D cutout rig).
#   tools/setup.sh                      # kit from the vendor/ submodule
#   KITS_DIR=~/dev tools/setup.sh       # kit from a sibling checkout (kit work in progress)
# Windows: tools/setup.ps1 (a directory junction, no admin rights needed).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${KITS_DIR:-}" ]; then
  MK="$KITS_DIR/godot-motion-kit"
else
  git submodule update --init --depth 1
  MK="$PWD/vendor/godot-motion-kit"
fi

mkdir -p addons
src="$(cd "$MK/addons/motion_kit" && pwd)"
rm -f addons/motion_kit
ln -s "$src" addons/motion_kit
echo "addons/motion_kit -> $src"
