#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${1:-release}
app_dir="$project_dir/dist/Codex Current.app"
contents_dir="$app_dir/Contents"

swift build --package-path "$project_dir" -c "$configuration"
bin_dir=$(swift build --package-path "$project_dir" -c "$configuration" --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$bin_dir/CodexCurrent" "$contents_dir/MacOS/CodexCurrent"
cp "$project_dir/Support/Info.plist" "$contents_dir/Info.plist"
cp -R "$project_dir/Sources/CodexCurrent/Resources/en.lproj" "$contents_dir/Resources/en.lproj"
cp -R "$project_dir/Sources/CodexCurrent/Resources/zh-Hans.lproj" "$contents_dir/Resources/zh-Hans.lproj"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
