#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
demo_pkg="${repo_root}/Example/DemoPackage"

export KAWARIMI_LINUX_CI=1
export KAWARIMI_CONFIG_WATCH=0
export HOST=127.0.0.1
export PORT=8080

cd "${demo_pkg}"
bin_dir="$(swift build --product DemoServer --show-bin-path)"
binary="${bin_dir}/DemoServer"

if [[ ! -x "${binary}" ]]; then
  echo "DemoServer not built; run install" >&2
  exit 1
fi

exec "${binary}"