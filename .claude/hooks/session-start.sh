#!/bin/bash
# Installs the pinned Godot (headless-capable Linux build) for Claude Code on the web,
# so tests and the headless sim can run. Keep GODOT_VERSION in sync with CLAUDE.md.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7.2"
NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
INSTALL_DIR="${HOME}/.local/share/godot/${GODOT_VERSION}"
BIN_DIR="${HOME}/.local/bin"

if [ ! -x "${INSTALL_DIR}/${NAME}" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "${TMP}"' EXIT
  curl -fsSL --retry 4 -o "${TMP}/${NAME}.zip" "${BASE_URL}/${NAME}.zip"
  curl -fsSL --retry 4 -o "${TMP}/SHA512-SUMS.txt" "${BASE_URL}/SHA512-SUMS.txt"
  (cd "${TMP}" && grep " ${NAME}.zip\$" SHA512-SUMS.txt | sha512sum -c --quiet -)
  mkdir -p "${INSTALL_DIR}"
  unzip -oq "${TMP}/${NAME}.zip" -d "${INSTALL_DIR}"
  chmod +x "${INSTALL_DIR}/${NAME}"
fi

mkdir -p "${BIN_DIR}"
ln -sf "${INSTALL_DIR}/${NAME}" "${BIN_DIR}/godot"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "${CLAUDE_ENV_FILE}"
fi

# Build the .godot/ import cache (class_name registry) so GUT can run headless.
"${BIN_DIR}/godot" --headless --path "${CLAUDE_PROJECT_DIR:-$(pwd)}" --import >/dev/null 2>&1 || true
