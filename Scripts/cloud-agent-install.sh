#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

export KAWARIMI_LINUX_CI=1

if ! command -v swift >/dev/null 2>&1; then
  echo "swift not found. Use base image swift:6.2-noble (see .cursor/environment.json)." >&2
  exit 1
fi

if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory "$repo_root" 2>/dev/null || true
fi

swift package resolve
swift build

cd Example/DemoPackage
swift package resolve
swift build --product DemoSpecWireExport
# DemoServer (Vapor) requires base image swift:6.2-noble (see .github/workflows/ci.yaml).
if [[ "${KAWARIMI_BUILD_DEMOSERVER:-}" == "1" ]]; then
  swift build --product DemoServer
fi