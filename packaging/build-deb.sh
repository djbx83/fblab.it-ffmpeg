#!/usr/bin/env bash
# Converte l'artifact statico prodotto da FFmpeg-Builds (tar.xz linux) in un .deb.
#
# Uso: build-deb.sh <artifact.tar.xz> <amd64|arm64> <outdir>
#
# Variabili opzionali:
#   PKG_NAME    nome pacchetto           (default: ffmpeg-nonfree-static)
#   MAINTAINER  campo Maintainer         (default: ffmpeg-nightly <noreply@localhost>)
#   BUILD_DATE  YYYYMMDD per la versione (default: data UTC corrente)
#   BUILD_RUN   numero di run CI, rende unica la versione di build dello stesso giorno
set -euo pipefail

ARTIFACT="$1"
ARCH="$2"
OUTDIR="$3"

PKG_NAME="${PKG_NAME:-ffmpeg-nonfree-static}"
MAINTAINER="${MAINTAINER:-ffmpeg-nightly <noreply@localhost>}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y%m%d)}"

case "$ARCH" in
    amd64|arm64) ;;
    *) echo "Architettura non supportata: $ARCH" >&2; exit 1 ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

tar -C "$WORK" -xJf "$ARTIFACT"
SRC="$(find "$WORK" -mindepth 1 -maxdepth 1 -type d | head -n1)"
BUILD_NAME="$(basename "$SRC")"     # es. ffmpeg-N-121234-gabcdef1234-linux64-nonfree

# Versione upstream: "N-121234-gabcdef1234" (master) oppure "n8.1-12-gabc" (release)
UPSTREAM="${BUILD_NAME#ffmpeg-}"
UPSTREAM="${UPSTREAM%-linux*}"
# Versione Debian monotona: data + upstream sanificato (dpkg confronta i numeri numericamente)
if [[ -n "${BUILD_RUN:-}" ]]; then
    DEB_VERSION="${BUILD_DATE}.${BUILD_RUN}+${UPSTREAM//-/.}"
else
    DEB_VERSION="${BUILD_DATE}+${UPSTREAM//-/.}"
fi

ROOT="$WORK/pkgroot"
install -d "$ROOT/DEBIAN" "$ROOT/usr/bin" \
    "$ROOT/usr/share/man/man1" \
    "$ROOT/usr/share/doc/$PKG_NAME" \
    "$ROOT/usr/share/ffmpeg"

install -m 0755 "$SRC"/bin/* "$ROOT/usr/bin/"

if [[ -d "$SRC/man/man1" ]]; then
    for m in "$SRC"/man/man1/*.1; do
        gzip -9n -c "$m" > "$ROOT/usr/share/man/man1/$(basename "$m").gz"
    done
fi

[[ -d "$SRC/doc" ]] && cp -r "$SRC"/doc/. "$ROOT/usr/share/doc/$PKG_NAME/"
compgen -G "$SRC/presets/*.ffpreset" >/dev/null && install -m 0644 "$SRC"/presets/*.ffpreset "$ROOT/usr/share/ffmpeg/"

cat > "$ROOT/usr/share/doc/$PKG_NAME/README.build" <<EOF
Build:      $BUILD_NAME
Variante:   nonfree (--enable-nonfree): binari NON ridistribuibili.
Generato:   $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

INSTALLED_SIZE="$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)"

cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $DEB_VERSION
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Section: video
Priority: optional
Provides: ffmpeg
Conflicts: ffmpeg
Replaces: ffmpeg
Homepage: https://ffmpeg.org/
Description: FFmpeg static build (git master, nonfree, all libraries)
 Build statica giornaliera di FFmpeg da git master, variante nonfree
 basata su FFmpeg-Builds. Include ffmpeg, ffprobe e ffplay linkati
 staticamente, senza dipendenze runtime da librerie di sistema.
 .
 Upstream: $UPSTREAM
EOF

mkdir -p "$OUTDIR"
OUT="$OUTDIR/${PKG_NAME}_${DEB_VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$OUT" >/dev/null
echo "$OUT"
