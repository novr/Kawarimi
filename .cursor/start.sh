#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
demo_pkg="${repo_root}/Example/DemoPackage"
binary="${demo_pkg}/.build/x86_64-unknown-linux-gnu/debug/DemoServer"

export KAWARIMI_LINUX_CI=1
export KAWARIMI_CONFIG_WATCH=0
export HOST=127.0.0.1
export PORT=8080

if [[ ! -x "$binary" ]]; then
  echo "DemoServer not built; run Scripts/cloud-agent-install.sh first" >&2
  exit 1
fi

cd "$demo_pkg"
exec "$binary"