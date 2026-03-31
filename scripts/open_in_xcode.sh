#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCODE_APP="/Applications/Xcode.app"
DEVELOPER_DIR_PATH="${XCODE_APP}/Contents/Developer"

if [[ ! -d "${XCODE_APP}" ]]; then
  echo "Xcode.app não encontrado em /Applications."
  echo "Instale o Xcode e tente novamente."
  exit 1
fi

ACTIVE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"

echo "Abrindo o pacote no Xcode..."
/usr/bin/open -a "${XCODE_APP}" "${REPO_ROOT}/Package.swift"

if [[ "${ACTIVE_DEVELOPER_DIR}" != "${DEVELOPER_DIR_PATH}" ]]; then
  echo
  echo "Aviso: o developer directory ativo ainda aponta para:"
  echo "  ${ACTIVE_DEVELOPER_DIR:-<não definido>}"
  echo
  echo "Para o xcodebuild/xed funcionarem no terminal, execute:"
  echo "  sudo xcode-select -s ${DEVELOPER_DIR_PATH}"
fi
