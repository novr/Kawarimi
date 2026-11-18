#!/usr/bin/env bash
# Idempotent Swift 6.2 toolchain on Ubuntu 24.04 when not using the swift Docker base image.
set -euo pipefail

if command -v swift >/dev/null 2>&1; then
  swift --version
  exit 0
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends \
  ca-certificates curl git xz-utils libncurses6 libcurl4-openssl-dev libpython3.12-dev libxml2-dev

SWIFT_VERSION="6.2.1"
SWIFT_TAR="swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"
SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION%%.*}.${SWIFT_VERSION##*.}-release/ubuntu2404/${SWIFT_TAR%.tar.gz}/${SWIFT_TAR}"
INSTALL_DIR="/opt/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
curl -fsSL "$SWIFT_URL" -o "${tmpdir}/${SWIFT_TAR}"
${SUDO} mkdir -p /opt
${SUDO} tar -xzf "${tmpdir}/${SWIFT_TAR}" -C /opt

for bin in "${INSTALL_DIR}/usr/bin/"*; do
  name="$(basename "$bin")"
  ${SUDO} ln -sf "$bin" "/usr/local/bin/${name}"
done

swift --version