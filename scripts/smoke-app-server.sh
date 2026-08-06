#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
smoke_dir=$(mktemp -d "${TMPDIR:-/tmp}/codexcurrent-smoke.XXXXXX")
trap 'rm -rf "$smoke_dir"' EXIT

swiftc \
  "$project_dir/Sources/CodexCurrent/Models/DashboardModels.swift" \
  "$project_dir/Sources/CodexCurrent/Services/CodexExecutableLocator.swift" \
  "$project_dir/Sources/CodexCurrent/Services/CodexAppServerClient.swift" \
  "$project_dir/Tests/AppServerSmoke.swift" \
  -o "$smoke_dir/CodexCurrentAppServerSmoke"

"$smoke_dir/CodexCurrentAppServerSmoke"
