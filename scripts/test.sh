#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/codexcurrent-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

swiftc \
  "$project_dir/Sources/CodexCurrent/Models/DashboardModels.swift" \
  "$project_dir/Sources/CodexCurrent/Services/LocalProcessRunner.swift" \
  "$project_dir/Sources/CodexCurrent/Services/CodexDesktopTaskMonitor.swift" \
  "$project_dir/Sources/CodexCurrent/Services/UsageEstimator.swift" \
  "$project_dir/Sources/CodexCurrent/Services/HistoryStore.swift" \
  "$project_dir/Tests/SelfTest.swift" \
  -o "$test_dir/CodexCurrentSelfTest"

"$test_dir/CodexCurrentSelfTest"
swift build --package-path "$project_dir"
