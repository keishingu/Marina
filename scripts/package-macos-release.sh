#!/bin/bash

set -euo pipefail

readonly script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly project_directory="$(cd "${script_directory}/.." && pwd)"
readonly output_directory="${project_directory}/build/release"
readonly app_path="${output_directory}/DerivedData/Build/Products/Release/Marina.app"
readonly archive_path="${output_directory}/Marina-macos-universal.zip"
readonly checksum_path="${archive_path}.sha256"

if [[ ! -d "${app_path}" ]]; then
  echo "error: package対象のアプリが見つかりません: ${app_path}" >&2
  exit 1
fi

rm -f "${archive_path}" "${checksum_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${archive_path}"
(
  cd "${output_directory}"
  shasum -a 256 "$(basename "${archive_path}")" > "$(basename "${checksum_path}")"
  shasum -a 256 -c "$(basename "${checksum_path}")"
)

echo "Packaged ${archive_path}"
echo "Checksum ${checksum_path}"
