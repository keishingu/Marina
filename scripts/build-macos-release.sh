#!/bin/bash

set -euo pipefail

readonly script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly project_directory="$(cd "${script_directory}/.." && pwd)"
readonly output_directory="${project_directory}/build/release"
readonly derived_data_directory="${output_directory}/DerivedData"
readonly app_path="${derived_data_directory}/Build/Products/Release/Marina.app"
readonly archive_path="${output_directory}/Marina-macos-universal.zip"
readonly build_number="${BUILD_NUMBER:?error: BUILD_NUMBER が指定されていません}"
readonly signing_identity="${SIGNING_IDENTITY:?error: SIGNING_IDENTITY が指定されていません}"

if [[ "${signing_identity}" != "Developer ID Application:"* ]]; then
  echo "error: Developer ID Application証明書ではありません: ${signing_identity}" >&2
  exit 1
fi

mkdir -p "${output_directory}"

xcodebuild \
  -project "${project_directory}/Marina.xcodeproj" \
  -scheme Marina \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${derived_data_directory}" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CURRENT_PROJECT_VERSION="${build_number}" \
  build

if [[ ! -d "${app_path}" ]]; then
  echo "error: ビルド済みアプリが見つかりません: ${app_path}" >&2
  exit 1
fi

readonly executable_path="${app_path}/Contents/MacOS/Marina"
readonly icon_path="${app_path}/Contents/Resources/AppIcon.icns"

if [[ ! -f "${icon_path}" ]]; then
  echo "error: AppIcon がアプリに組み込まれていません: ${icon_path}" >&2
  exit 1
fi

readonly architectures="$(lipo -archs "${executable_path}")"
if [[ " ${architectures} " != *" arm64 "* || " ${architectures} " != *" x86_64 "* ]]; then
  echo "error: Universal binary ではありません: ${architectures}" >&2
  exit 1
fi

codesign \
  --force \
  --sign "${signing_identity}" \
  --options runtime \
  --timestamp \
  --verbose \
  "${app_path}"
codesign --verify --deep --strict --verbose=2 "${app_path}"
codesign --display --verbose=4 "${app_path}"

"${script_directory}/package-macos-release.sh"

echo "Created ${archive_path}"
echo "Architectures: ${architectures}"
echo "App icon: ${icon_path}"
echo "Signing identity: ${signing_identity}"
