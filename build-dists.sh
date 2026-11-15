#!/usr/bin/env bash
# Rigenera dists/ firmato per un archivio APT a partire dal suo pool/.
#
# Uso: build-dists.sh <archive_root> <archive_label>
#   <archive_root>/pool/<suite>/<component>/<prefix>/<package>/*.deb
#
# Variabili:
#   GPG_KEY_ID       fingerprint chiave di firma (obbligatoria)
#   GPG_PASSPHRASE   opzionale
#   ARCHES           default "amd64 arm64" (i pacchetti Architecture: all
#                    finiscono automaticamente in tutti gli indici)
#   COMPONENT        default main
set -euo pipefail

ROOT="$1"
LABEL="$2"

: "${GPG_KEY_ID:?GPG_KEY_ID non impostata}"
ARCHES="${ARCHES:-amd64 arm64}"
COMPONENT="${COMPONENT:-main}"

cd "$ROOT"
rm -rf dists

GPG_ARGS=( --batch --yes --local-user "$GPG_KEY_ID" --digest-algo SHA512 )
[[ -n "${GPG_PASSPHRASE:-}" ]] && GPG_ARGS+=( --pinentry-mode loopback --passphrase-fd 0 )
gpg_sign() {
    if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
        printf '%s' "$GPG_PASSPHRASE" | gpg "${GPG_ARGS[@]}" "$@"
    else
        gpg "${GPG_ARGS[@]}" "$@" </dev/null
    fi
}

shopt -s nullglob
for sdir in pool/*/; do
    suite="$(basename "$sdir")"
    for arch in $ARCHES; do
        bdir="dists/$suite/$COMPONENT/binary-$arch"
        mkdir -p "$bdir"
        apt-ftparchive --arch "$arch" packages "pool/$suite" > "$bdir/Packages"
        gzip -9n -k "$bdir/Packages"
        xz -9 -k "$bdir/Packages"
    done

    apt-ftparchive \
        -o "APT::FTPArchive::Release::Origin=fblab.it" \
        -o "APT::FTPArchive::Release::Label=$LABEL" \
        -o "APT::FTPArchive::Release::Suite=$suite" \
        -o "APT::FTPArchive::Release::Codename=$suite" \
        -o "APT::FTPArchive::Release::Architectures=$ARCHES" \
        -o "APT::FTPArchive::Release::Components=$COMPONENT" \
        -o "APT::FTPArchive::Release::Description=fblab.it $LABEL packages" \
        release "dists/$suite" > "dists/$suite/Release.tmp"
    mv "dists/$suite/Release.tmp" "dists/$suite/Release"

    gpg_sign --clearsign -o "dists/$suite/InRelease" "dists/$suite/Release"
    gpg_sign --armor --detach-sign -o "dists/$suite/Release.gpg" "dists/$suite/Release"
    echo "suite $suite: $(grep -c '^Package:' dists/"$suite"/"$COMPONENT"/binary-*/Packages | paste -sd' ')"
done

