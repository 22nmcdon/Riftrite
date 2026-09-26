#!/bin/bash
# Installs the pinned Godot (Linux, headless-capable) as `godot`, checksum-
# verified. With --templates, also installs the Windows and macOS export
# templates. Used by the GitHub workflows; the version comes from
# GODOT_VERSION (keep it in sync with CLAUDE.md's "Pinned versions").
set -euo pipefail

VERSION="${GODOT_VERSION:?set GODOT_VERSION, e.g. 4.7.2}"
BASE_URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
NAME="Godot_v${VERSION}-stable_linux.x86_64"
INSTALL_DIR="${HOME}/.local/share/godot/${VERSION}"
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"
BIN_DIR="${HOME}/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

curl -fsSL --retry 4 -o "${TMP}/SHA512-SUMS.txt" "${BASE_URL}/SHA512-SUMS.txt"

if [ ! -x "${INSTALL_DIR}/${NAME}" ]; then
  curl -fsSL --retry 4 -o "${TMP}/${NAME}.zip" "${BASE_URL}/${NAME}.zip"
  (cd "${TMP}" && grep " ${NAME}.zip\$" SHA512-SUMS.txt | sha512sum -c --quiet -)
  mkdir -p "${INSTALL_DIR}"
  unzip -oq "${TMP}/${NAME}.zip" -d "${INSTALL_DIR}"
  chmod +x "${INSTALL_DIR}/${NAME}"
fi
mkdir -p "${BIN_DIR}"
ln -sf "${INSTALL_DIR}/${NAME}" "${BIN_DIR}/godot"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${BIN_DIR}" >> "${GITHUB_PATH}"
fi

if [ "${1:-}" = "--templates" ] && [ ! -f "${TEMPLATES_DIR}/version.txt" ]; then
  TPZ="Godot_v${VERSION}-stable_export_templates.tpz"
  curl -fsSL --retry 4 -o "${TMP}/${TPZ}" "${BASE_URL}/${TPZ}"
  (cd "${TMP}" && grep " ${TPZ}\$" SHA512-SUMS.txt | sha512sum -c --quiet -)
  mkdir -p "${TEMPLATES_DIR}"
  # Only the desktop templates the presets use (the full set is 1.3 GB).
  unzip -oqj "${TMP}/${TPZ}" templates/version.txt templates/windows_release_x86_64.exe \
    templates/windows_release_x86_64_console.exe templates/macos.zip -d "${TEMPLATES_DIR}"
fi
