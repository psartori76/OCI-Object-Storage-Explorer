#!/bin/bash
set -euo pipefail

DERIVED_DATA_DIR="${HOME}/Library/Developer/Xcode/DerivedData"
SOURCE_PACKAGES_DIR="${HOME}/Library/Developer/Xcode/DerivedData"

echo "Feche o Xcode antes de continuar."
echo
echo "Este script remove somente caches do projeto OCIExploreriOS."
echo

find "${DERIVED_DATA_DIR}" -maxdepth 1 -type d -name 'OCIExploreriOS-*' -print -exec rm -rf {} +

echo
echo "Caches do projeto iOS removidos."
echo "Próximos passos:"
echo "1. Abra novamente Apps/OCIExploreriOS/OCIExploreriOS.xcodeproj"
echo "2. Selecione um iPhone Simulator"
echo "3. Use Product > Clean Build Folder"
echo "4. Rode o projeto novamente"
