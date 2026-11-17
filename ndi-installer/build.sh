#!/usr/bin/env bash
# Costruisce ndi-runtime-installer_<VERSION>_<arch>.deb (nessun binario NDI dentro).
# Uso: build.sh <amd64|arm64> <outdir>
set -euo pipefail
ARCH="$1"; OUT="$2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$HERE/VERSION")"
MAINT="${MAINTAINER:-ffmpeg-nightly <noreply@localhost>}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$HERE" log -1 --format=%ct -- . 2>/dev/null || date +%s)}"

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
chmod 0755 "$ROOT"   # mktemp crea 0700: diventerebbe il modo di ./ nel pacchetto
chmod 0755 "$ROOT"
install -d "$ROOT/DEBIAN" "$ROOT/usr/sbin" "$ROOT/etc/ld.so.conf.d" "$ROOT/usr/share/doc/ndi-runtime-installer"
install -m 0755 "$HERE/update-ndi-runtime" "$ROOT/usr/sbin/"
install -m 0644 "$HERE/ndi-runtime.conf" "$ROOT/etc/ld.so.conf.d/ndi-runtime.conf"
install -m 0755 "$HERE/debian/config" "$HERE/debian/postinst" "$HERE/debian/postrm" "$ROOT/DEBIAN/"
install -m 0644 "$HERE/debian/templates" "$ROOT/DEBIAN/"
echo /etc/ld.so.conf.d/ndi-runtime.conf > "$ROOT/DEBIAN/conffiles"
cat > "$ROOT/usr/share/doc/ndi-runtime-installer/README" <<'DOC'
Installer for the NDI runtime (libndi.so.6), used by ffmpeg's libndi_newtek device.
The library is downloaded from ndi.video at install time (update-ndi-runtime),
it is not contained in this package. NDI(R) is a registered trademark of Vizrt NDI AB.
https://ndi.video/
DOC
cat > "$ROOT/DEBIAN/control" <<CTL
Package: ndi-runtime-installer
Version: $VERSION
Architecture: $ARCH
Maintainer: $MAINT
Section: non-free/video
Priority: optional
Depends: debconf (>= 0.5) | debconf-2.0, curl, ca-certificates, tar, gzip
Recommends: avahi-daemon
Description: NDI runtime installer (downloads libndi from ndi.video)
 Downloads the NDI SDK for Linux from ndi.video at install time and installs
 only its runtime library (libndi.so.6) in /usr/lib/ndi-runtime, registered
 with ldconfig. Needed by ffmpeg -f libndi_newtek.
 .
 Requires accepting the NDI SDK License Agreement (debconf question).
 Run update-ndi-runtime to download the latest runtime again.
CTL
find "$ROOT" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
mkdir -p "$OUT"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$OUT/ndi-runtime-installer_${VERSION}_${ARCH}.deb"
