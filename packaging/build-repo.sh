#!/usr/bin/env bash
# Genera un repository APT firmato a partire da una directory di .deb.
#
# Uso: build-repo.sh <dir_con_deb> <repo_outdir>
#
# Richiede chiave GPG già importata nel keyring.
# Variabili:
#   GPG_KEY_ID      fingerprint/ID della chiave di firma (obbligatoria)
#   GPG_PASSPHRASE  passphrase della chiave (opzionale)
#   SUITE           nome suite/codename (default: ffmpeg)
#   COMPONENT       componente          (default: main)
#   ARCHES          architetture        (default: "amd64 arm64")
#   ORIGIN / LABEL  campi Release       (default: ffmpeg-nightly)
set -euo pipefail

DEBDIR="$1"
REPO="$2"

: "${GPG_KEY_ID:?GPG_KEY_ID non impostata}"
SUITE="${SUITE:-ffmpeg}"
COMPONENT="${COMPONENT:-main}"
ARCHES="${ARCHES:-amd64 arm64}"
ORIGIN="${ORIGIN:-ffmpeg-nightly}"
LABEL="${LABEL:-ffmpeg-nightly}"

rm -rf "$REPO"
mkdir -p "$REPO/dists/$SUITE"

# pool/<component>/<iniziale>/<pacchetto>/
shopt -s nullglob
debs=( "$DEBDIR"/*.deb )
(( ${#debs[@]} )) || { echo "Nessun .deb in $DEBDIR" >&2; exit 1; }
for deb in "${debs[@]}"; do
    pkg="$(dpkg-deb -f "$deb" Package)"
    dest="$REPO/pool/$COMPONENT/${pkg:0:1}/$pkg"
    mkdir -p "$dest"
    cp "$deb" "$dest/"
done

cd "$REPO"
for arch in $ARCHES; do
    bdir="dists/$SUITE/$COMPONENT/binary-$arch"
    mkdir -p "$bdir"
    apt-ftparchive --arch "$arch" packages "pool/$COMPONENT" > "$bdir/Packages"
    gzip -9n -k "$bdir/Packages"
    xz -9 -k "$bdir/Packages"
done

apt-ftparchive \
    -o "APT::FTPArchive::Release::Origin=$ORIGIN" \
    -o "APT::FTPArchive::Release::Label=$LABEL" \
    -o "APT::FTPArchive::Release::Suite=$SUITE" \
    -o "APT::FTPArchive::Release::Codename=$SUITE" \
    -o "APT::FTPArchive::Release::Architectures=$ARCHES" \
    -o "APT::FTPArchive::Release::Components=$COMPONENT" \
    -o "APT::FTPArchive::Release::Description=FFmpeg nightly static builds" \
    release "dists/$SUITE" > "dists/$SUITE/Release.tmp"
mv "dists/$SUITE/Release.tmp" "dists/$SUITE/Release"

GPG_ARGS=( --batch --yes --local-user "$GPG_KEY_ID" --digest-algo SHA512 )
if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
    GPG_ARGS+=( --pinentry-mode loopback --passphrase-fd 0 )
fi

gpg_sign() { if [[ -n "${GPG_PASSPHRASE:-}" ]]; then printf '%s' "$GPG_PASSPHRASE" | gpg "${GPG_ARGS[@]}" "$@"; else gpg "${GPG_ARGS[@]}" "$@" </dev/null; fi; }

gpg_sign --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
gpg_sign --armor --detach-sign -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"

# Chiave pubblica per i client (binaria, da usare con signed-by=)
gpg --batch --yes --export "$GPG_KEY_ID" > "ffmpeg-nightly-archive-keyring.gpg"

find . -type f | sort
