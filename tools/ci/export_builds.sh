#!/bin/bash
# Exports the Windows and macOS playtest builds (export_presets.cfg) and zips
# each with HOW-TO-PLAY.txt into build/dist/Riftrite-<platform>-<label>.zip.
# Needs `godot` and the export templates (tools/ci/install_godot.sh --templates).
# Usage: tools/ci/export_builds.sh [label]   (default: the short commit hash)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LABEL="${1:-$(git -C "${ROOT}" rev-parse --short HEAD)}"
cd "${ROOT}"
rm -rf build
mkdir -p build/windows build/macos build/dist

godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Windows Desktop" build/windows/Riftrite.exe
godot --headless --path . --export-release "macOS" build/macos/Riftrite.zip
test -s build/windows/Riftrite.exe
test -s build/macos/Riftrite.zip

cp tools/ci/HOW-TO-PLAY.txt build/windows/
(cd build/windows && zip -q -9 "../dist/Riftrite-windows-${LABEL}.zip" Riftrite.exe HOW-TO-PLAY.txt)
cp build/macos/Riftrite.zip "build/dist/Riftrite-macos-${LABEL}.zip"
(cd tools/ci && zip -q "../../build/dist/Riftrite-macos-${LABEL}.zip" HOW-TO-PLAY.txt)
ls -l build/dist
