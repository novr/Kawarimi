#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

export KAWARIMI_LINUX_CI=1

bash "${repo_root}/Scripts/ensure-swift-linux.sh"

if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory "$repo_root" 2>/dev/null || true
fi

swift package resolve
swift build

cd Example/DemoPackage
swift package resolve
swift build --product DemoSpecWireExport
# DemoServer (Vapor) needs the swift:6.2-noble base image; tarball Swift on ubuntu often cannot compile BoringSSL.
if [[ "${KAWARIMI_BUILD_DEMOSERVER:-}" == "1" ]]; then
  swift build --product DemoServer
fi