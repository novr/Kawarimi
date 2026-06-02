#!/usr/bin/env bash
# Local-only: run the same swift test sequence as ubuntu CI (KAWARIMI_LINUX_CI=1).
# Not used in GitHub Actions. Requires Docker. Run from anywhere in the repo.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

# Docker must see the same absolute paths as the host (required for git worktrees:
# .git is a file pointing at $gitdir outside the checkout tree).
docker_volumes=(-v "${repo_root}:${repo_root}")
git_metadata="${repo_root}/.git"
if [[ -f "${git_metadata}" ]]; then
  gitdir="$(sed -n 's/^gitdir: //p' "${git_metadata}" | head -1)"
  if [[ -n "${gitdir}" ]]; then
    gitdir="$(cd "${gitdir}" && pwd)"
    git_common="$(cd "${gitdir}/../.." && pwd)"
    if [[ -d "${git_common}" ]]; then
      docker_volumes+=(-v "${git_common}:${git_common}")
    fi
  fi
fi

# Isolated from macOS `.build` and from older docker runs that used `-w /workspace`.
linux_build_path=".build/linux-docker"

docker run --rm \
  "${docker_volumes[@]}" \
  -w "${repo_root}" \
  -e KAWARIMI_LINUX_CI=1 \
  -e KAWARIMI_SWIFT_BUILD_PATH="${linux_build_path}" \
  -e REPO_ROOT="${repo_root}" \
  swift:6.2-noble \
  bash -lc '
    set -euo pipefail
    if command -v git >/dev/null 2>&1; then
      git config --global --add safe.directory "$REPO_ROOT" 2>/dev/null || true
    fi
    swift test --build-path "$KAWARIMI_SWIFT_BUILD_PATH" "$@"
    cd Example/DemoPackage && swift test --build-path "$KAWARIMI_SWIFT_BUILD_PATH" "$@"
  ' -- "$@"
