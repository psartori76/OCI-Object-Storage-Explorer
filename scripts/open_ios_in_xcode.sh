#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
XCODE_APP="/Applications/Xcode.app"
IOS_PROJECT="${REPO_ROOT}/Apps/OCIExploreriOS/OCIExploreriOS.xcodeproj"

if [[ ! -d "${XCODE_APP}" ]]; then
  echo "Xcode.app não encontrado em /Applications."
  exit 1
fi

if [[ ! -d "${IOS_PROJECT}" ]]; then
  echo "Projeto iOS não encontrado em:"
  echo "  ${IOS_PROJECT}"
  exit 1
fi

echo "Abrindo projeto iOS no Xcode..."
/usr/bin/open -a "${XCODE_APP}" "${IOS_PROJECT}"
