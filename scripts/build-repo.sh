#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
package_directory="${repository_root}/packages"
site_directory="${repository_root}/site"
pool_directory="${site_directory}/pool"

if [[ ! -d "${package_directory}" ]]; then
  echo "Không tìm thấy thư mục packages/. Hãy build tweak trước." >&2
  exit 1
fi

mapfile -d '' package_files < <(
  find "${package_directory}" -maxdepth 1 -type f -name '*.deb' -print0
)

if (( ${#package_files[@]} == 0 )); then
  echo "Không tìm thấy file .deb trong packages/." >&2
  exit 1
fi

rm -rf -- "${pool_directory}"
mkdir -p -- "${pool_directory}"
cp -- "${package_files[@]}" "${pool_directory}/"

cd -- "${site_directory}"
rm -f -- Packages Packages.gz Packages.bz2 Packages.xz Packages.zst Release InRelease Release.gpg

apt-ftparchive packages ./pool > Packages
gzip -9c Packages > Packages.gz
bzip2 -9c Packages > Packages.bz2
xz -9c Packages > Packages.xz
zstd -q -19 -c Packages > Packages.zst

apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="DevicePersona" \
  -o APT::FTPArchive::Release::Label="DevicePersona" \
  -o APT::FTPArchive::Release::Suite="stable" \
  -o APT::FTPArchive::Release::Codename="stable" \
  -o APT::FTPArchive::Release::Architectures="iphoneos-arm" \
  -o APT::FTPArchive::Release::Components="main" \
  -o APT::FTPArchive::Release::Description="DevicePersona rootful packages for iOS 15" \
  release . > Release

echo "Đã tạo Sileo repo trong ${site_directory}:"
find . -maxdepth 2 -type f -print | sort
