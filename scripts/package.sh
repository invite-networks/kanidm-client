#!/usr/bin/env bash
# Builds kanidm-unixd, libpam-kanidm and libnss-kanidm from the pinned upstream
# commit and writes them to dist/.
#   scripts/package.sh [revision]
# revision is the INVITE part of the package version, for example invite1.
# Without it the packages are marked as a local build (invite0).
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
# shellcheck source=upstream.env
. ./upstream.env

revision=${1:-invite0}
[[ $revision =~ ^invite[0-9]+$ ]] || { echo "revision must look like invite1, got: $revision" >&2; exit 1; }
version="${KANIDM_TAG#v}-${revision}"
src=$root/build/src
dist=$root/dist

# Fetch the tag and refuse anything but the pinned commit.
if [[ ! -d $src/.git ]]; then
  git clone --quiet --depth 1 --branch "$KANIDM_TAG" https://github.com/kanidm/kanidm.git "$src"
fi
git config --global --add safe.directory "$src"
head=$(git -C "$src" rev-parse HEAD)
[[ $head == "$KANIDM_COMMIT" ]] || { echo "upstream $KANIDM_TAG is $head, expected $KANIDM_COMMIT" >&2; exit 1; }
git -C "$src" checkout --quiet -- .

cd "$src"
# cargo honours CARGO_TARGET_DIR. Local builds set it off the bind mount.
out=${CARGO_TARGET_DIR:-$src/target}
target=$(rustc -vV | awk '/^host:/ {print $2}')
export RUSTUP_TOOLCHAIN=$RUST_VERSION
export KANIDM_BUILD_PROFILE=release_debian
echo "Building Kanidm client $version for $target with Rust $RUST_VERSION"

# Only the client side. The server is built by invite-kanidm.
cargo build --release --target "$target" \
  --bin kanidm_unixd --bin kanidm_unixd_tasks \
  --bin kanidm_ssh_authorizedkeys --bin kanidm-unix
cargo build --release --target "$target" -p pam_kanidm -p nss_kanidm

# kanidm-unixd's metadata points at a generated changelog.
mkdir -p target/debian
cat > target/debian/changelog <<EOF
kanidm ($version) stable; urgency=medium

  * Upstream Kanidm $KANIDM_TAG ($KANIDM_COMMIT), built by INVITE Networks.

 -- INVITE Networks <aasay@users.noreply.github.com>  $(date -uR)
EOF

# kanidm-unixd must only install with the PAM and NSS modules from the same build.
manifest=unix_integration/resolver_kanidm/Cargo.toml
for dep in libpam-kanidm libnss-kanidm; do
  [[ $(grep -Ec "^[[:space:]]*\"$dep\"[[:space:]]*,?[[:space:]]*$" "$manifest") -eq 1 ]] \
    || { echo "expected one unversioned $dep in $manifest" >&2; exit 1; }
  sed -i -E "s|^([[:space:]]*)\"$dep\"|\\1\"$dep (= $version)\"|" "$manifest"
done

rm -rf "$out/$target/debian"
for crate in kanidm_unix_int pam_kanidm nss_kanidm; do
  cargo deb -p "$crate" --no-build --target "$target" --deb-version "$version" --multiarch=foreign
done
git checkout --quiet -- "$manifest"

# Check the result rather than trusting the edits above.
rm -rf "$dist"
mkdir -p "$dist"
cp "$out/$target/debian/"*.deb "$dist/"
cd "$dist"
for pkg in kanidm-unixd libpam-kanidm libnss-kanidm; do
  ls "${pkg}_${version}_"*.deb >/dev/null || { echo "missing $pkg $version" >&2; exit 1; }
done
depends=$(dpkg-deb -f kanidm-unixd_"${version}"_*.deb Depends)
for dep in libpam-kanidm libnss-kanidm; do
  grep -Fq "$dep (= $version)" <<<"$depends" || { echo "kanidm-unixd does not pin $dep: $depends" >&2; exit 1; }
done
sha256sum ./*.deb > SHA256SUMS
echo "Built:"
cat SHA256SUMS
