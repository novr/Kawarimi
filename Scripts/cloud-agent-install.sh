#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

export KAWARIMI_LINUX_CI=1

expected_image="$("${repo_root}/Scripts/swift-docker-image.sh")"
configured_image="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["image"])' "${repo_root}/.cursor/environment.json")"
if [[ "${configured_image}" != "${expected_image}" ]]; then
  echo "Cloud Agent image mismatch: .cursor/environment.json has ${configured_image}, expected ${expected_image} (from .swift-version)" >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "swift not found: set base image to ${expected_image} (.cursor/environment.json)" >&2
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
swift build --product DemoServer
