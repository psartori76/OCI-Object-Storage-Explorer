#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCODE_APP="/Applications/Xcode.app"
DEVELOPER_DIR_PATH="${XCODE_APP}/Contents/Developer"
PACKAGE_FILE="${REPO_ROOT}/Package.swift"

echo "== Xcode Doctor =="
echo

if [[ -f "${PACKAGE_FILE}" ]]; then
  echo "[ok] Package.swift encontrado"
else
  echo "[erro] Package.swift não encontrado em ${REPO_ROOT}"
  exit 1
fi

if [[ -d "${XCODE_APP}" ]]; then
  echo "[ok] Xcode.app encontrado em /Applications"
else
  echo "[erro] Xcode.app não encontrado em /Applications"
  exit 1
fi

ACTIVE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "${ACTIVE_DEVELOPER_DIR}" == "${DEVELOPER_DIR_PATH}" ]]; then
  echo "[ok] xcode-select aponta para o Xcode.app"
else
  echo "[aviso] xcode-select aponta para:"
  echo "        ${ACTIVE_DEVELOPER_DIR:-<não definido>}"
  echo "        Para usar xcodebuild/xed no terminal:"
  echo "        sudo xcode-select -s ${DEVELOPER_DIR_PATH}"
fi

echo
echo "Versão do Xcode:"
/usr/bin/env DEVELOPER_DIR="${DEVELOPER_DIR_PATH}" xcodebuild -version || true

if [[ "${1:-}" == "--build" ]]; then
  echo
  echo "Build Swift Package:"
  (
    cd "${REPO_ROOT}"
    SWIFTPM_MODULECACHE_OVERRIDE="${REPO_ROOT}/.build/module-cache" \
    CLANG_MODULE_CACHE_PATH="${REPO_ROOT}/.build/module-cache" \
    /usr/bin/env DEVELOPER_DIR="${DEVELOPER_DIR_PATH}" xcrun swift build >/dev/null
  )
  echo "[ok] swift build concluído"
else
  echo
  echo "[info] Build não executado automaticamente."
  echo "       Para validar também o build, rode:"
  echo "       /bin/bash scripts/xcode_doctor.sh --build"
fi

echo
echo "Próximo passo sugerido:"
echo "  ./scripts/open_in_xcode.sh"
