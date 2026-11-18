#!/usr/bin/env bash
# Idempotent Swift toolchain on Ubuntu Noble when not using the swift Docker base image.
set -euo pipefail

# Swift.org uses "ubuntu2404" in the URL path and "ubuntu24.04" in archive/dir names.
readonly UBUNTU_VERSION="24.04"
readonly UBUNTU_SWIFT_SUFFIX="ubuntu${UBUNTU_VERSION}"
readonly UBUNTU_SWIFT_DL_SLUG="ubuntu${UBUNTU_VERSION//./}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version_file="${repo_root}/.swift-version"

if command -v swift >/dev/null 2>&1; then
  swift --version
  exit 0
fi

if [[ ! -f "${version_file}" ]]; then
  echo "Missing ${version_file} (required for Linux Swift bootstrap)" >&2
  exit 1
fi

SWIFT_VERSION="$(tr -d '[:space:]' < "${version_file}")"
if [[ -z "${SWIFT_VERSION}" ]] || [[ ! "${SWIFT_VERSION}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid .swift-version: '${SWIFT_VERSION}'" >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends \
  ca-certificates curl git xz-utils libncurses6 libcurl4-openssl-dev libpython3.12-dev libxml2-dev \
  build-essential libc++-dev libstdc++-12-dev

SWIFT_BUNDLE="swift-${SWIFT_VERSION}-RELEASE"
SWIFT_TAR="${SWIFT_BUNDLE}-${UBUNTU_SWIFT_SUFFIX}.tar.gz"
SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/${UBUNTU_SWIFT_DL_SLUG}/${SWIFT_BUNDLE}/${SWIFT_TAR}"
INSTALL_DIR="/opt/${SWIFT_BUNDLE}-${UBUNTU_SWIFT_SUFFIX}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
curl -fsSL "$SWIFT_URL" -o "${tmpdir}/${SWIFT_TAR}"
${SUDO} mkdir -p /opt
${SUDO} tar -xzf "${tmpdir}/${SWIFT_TAR}" -C /opt

if [[ ! -d "${INSTALL_DIR}/usr/bin" ]]; then
  echo "Swift install layout not found at ${INSTALL_DIR}" >&2
  exit 1
fi

for bin in "${INSTALL_DIR}/usr/bin/"*; do
  name="$(basename "$bin")"
  ${SUDO} ln -sf "$bin" "/usr/local/bin/${name}"
done

swift --version