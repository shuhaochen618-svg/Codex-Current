#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
smoke_dir=$(mktemp -d "${TMPDIR:-/tmp}/codexcurrent-local-smoke.XXXXXX")
trap 'rm -rf "$smoke_dir"' EXIT

swiftc \
  "$project_dir/Sources/CodexCurrent/Models/DashboardModels.swift" \
  "$project_dir/Sources/CodexCurrent/Services/LocalProcessRunner.swift" \
  "$project_dir/Sources/CodexCurrent/Services/VPNStatusClient.swift" \
  "$project_dir/Sources/CodexCurrent/Services/CodexDesktopTaskMonitor.swift" \
  "$project_dir/Tests/LocalStatusSmoke.swift" \
  -o "$smoke_dir/CodexCurrentLocalStatusSmoke"

"$smoke_dir/CodexCurrentLocalStatusSmoke"
