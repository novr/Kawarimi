#!/usr/bin/env bash
# Resolve the Linux Docker image from repo-root `.swift-version` (e.g. 6.4 → swift:6.4-noble).
# When GITHUB_OUTPUT is set, also writes version= and image= for workflow job outputs.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
version_file="${repo_root}/.swift-version"

if [[ ! -f "${version_file}" ]]; then
  echo "missing ${version_file}" >&2
  exit 1
fi

version="$(tr -d '[:space:]' < "${version_file}")"
if [[ -z "${version}" ]]; then
  echo "empty ${version_file}" >&2
  exit 1
fi

image="swift:${version}-noble"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=${version}"
    echo "image=${image}"
  } >> "${GITHUB_OUTPUT}"
fi

printf '%s\n' "${image}"
