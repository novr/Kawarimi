#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
demo_pkg="${repo_root}/Example/DemoPackage"

# Align with .cursor/environment.json install (DemoServer expected on swift:6.2-noble).
: "${KAWARIMI_BUILD_DEMOSERVER:=1}"

export KAWARIMI_LINUX_CI=1
export KAWARIMI_CONFIG_WATCH=0
export HOST=127.0.0.1
export PORT=8080

binary="${demo_pkg}/.build/x86_64-unknown-linux-gnu/debug/DemoServer"
if [[ ! -x "${binary}" ]] && command -v swift >/dev/null 2>&1; then
  bin_dir="$(cd "${demo_pkg}" && swift build --product DemoServer --show-bin-path 2>/dev/null)" || true
  if [[ -n "${bin_dir:-}" ]] && [[ -x "${bin_dir}/DemoServer" ]]; then
    binary="${bin_dir}/DemoServer"
  fi
fi

if [[ ! -x "${binary}" ]]; then
  if [[ "${KAWARIMI_BUILD_DEMOSERVER}" == "1" ]]; then
    echo "DemoServer missing; install with KAWARIMI_BUILD_DEMOSERVER=1 on image swift:6.2-noble" >&2
    exit 1
  fi
  echo "DemoServer not built; skipping start" >&2
  exit 0
fi

cd "${demo_pkg}"
exec "${binary}"