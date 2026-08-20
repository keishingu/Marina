#!/bin/bash

set -euo pipefail

readonly script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly project_directory="$(cd "${script_directory}/.." && pwd)"
readonly output_directory="${project_directory}/build/release"
readonly app_path="${output_directory}/DerivedData/Build/Products/Release/Marina.app"
readonly disk_image_path="${output_directory}/Marina-macos-universal.dmg"
readonly settings_path="${script_directory}/dmg/settings.py"
readonly background_path="${script_directory}/dmg/background.png"
readonly retina_background_path="${script_directory}/dmg/background@2x.png"
readonly signing_identity="${SIGNING_IDENTITY:?error: SIGNING_IDENTITY が指定されていません}"

if [[ ! -d "${app_path}" ]]; then
  echo "error: package対象のアプリが見つかりません: ${app_path}" >&2
  exit 1
fi
if [[ ! -f "${settings_path}" || ! -f "${background_path}" || ! -f "${retina_background_path}" ]]; then
  echo "error: DMGレイアウト用ファイルが見つかりません" >&2
  exit 1
fi
if ! command -v dmgbuild >/dev/null 2>&1; then
  echo "error: dmgbuildが見つかりません。scripts/requirements-dmg.txtをinstallしてください" >&2
  exit 1
fi
if [[ "${signing_identity}" != "Developer ID Application:"* ]]; then
  echo "error: Developer ID Application証明書ではありません: ${signing_identity}" >&2
  exit 1
fi

rm -f "${disk_image_path}"
dmgbuild \
  -s "${settings_path}" \
  -D "app_path=${app_path}" \
  -D "background_path=${background_path}" \
  Marina \
  "${disk_image_path}"
codesign \
  --force \
  --sign "${signing_identity}" \
  --timestamp \
  --verbose \
  "${disk_image_path}"
codesign --verify --verbose=2 "${disk_image_path}"
hdiutil verify "${disk_image_path}"

echo "Packaged ${disk_image_path}"
