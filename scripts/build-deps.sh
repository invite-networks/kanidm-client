#!/bin/sh
# Installs what package.sh needs on a Debian based Rust image (rust:<version>-trixie).
#   scripts/build-deps.sh
set -eu
cd "$(dirname "$0")/.."
# shellcheck source=upstream.env
. ./upstream.env

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential clang lld cmake pkg-config git jq dpkg-dev \
  libpam0g-dev libudev-dev libssl-dev libsystemd-dev

cargo install cargo-deb --version "$CARGO_DEB_VERSION" --locked
