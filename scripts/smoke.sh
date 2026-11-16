#!/bin/sh
# Installs the packages in dist/ on a clean Debian host or container and checks
# that every binary and module loads.
#   scripts/smoke.sh
set -eu
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
. /etc/os-release
echo "Smoke test on $PRETTY_NAME"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ./dist/*.deb

for bin in kanidm_unixd kanidm_unixd_tasks kanidm_ssh_authorizedkeys kanidm-unix; do
  path=/usr/sbin/$bin
  [ -x "$path" ] || { echo "missing $path" >&2; exit 1; }
  if ldd "$path" | grep -q 'not found'; then
    ldd "$path" >&2
    echo "$bin has unresolved libraries" >&2
    exit 1
  fi
done
/usr/sbin/kanidm_unixd --version

for lib in "$(dpkg -L libpam-kanidm | grep '/pam_kanidm\.so$')" "$(dpkg -L libnss-kanidm | grep '/libnss_kanidm\.so\.2$')"; do
  [ -f "$lib" ] || { echo "missing PAM or NSS module" >&2; exit 1; }
  if ldd "$lib" | grep -q 'not found'; then
    ldd "$lib" >&2
    echo "$lib has unresolved libraries" >&2
    exit 1
  fi
  echo "ok $lib"
done

dpkg-query -W kanidm-unixd libpam-kanidm libnss-kanidm
echo "Smoke test passed on $PRETTY_NAME"
