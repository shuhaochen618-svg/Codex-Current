#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
info_plist="$project_dir/Support/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")
architecture=$(uname -m)
archive_name="Codex-Current-v${version}-macOS-${architecture}.zip"
archive="$project_dir/dist/$archive_name"
checksum="$archive.sha256"

"$project_dir/scripts/build-app.sh" release

rm -f "$archive" "$checksum"
ditto -c -k --sequesterRsrc --keepParent "$project_dir/dist/Codex Current.app" "$archive"
(
    cd "$project_dir/dist"
    shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

codesign --verify --deep --strict "$project_dir/dist/Codex Current.app"

echo "$archive"
echo "$checksum"
