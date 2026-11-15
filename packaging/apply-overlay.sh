#!/usr/bin/env bash
# Aggiunge gli script di scripts.d/ di questo repo a FFmpeg-Builds e li registra
# come dipendenze di zz-final.sh: solo gli stage elencati lì entrano nella build.
#
# Uso: apply-overlay.sh <ffbuilds_dir>
set -euo pipefail

FFB="$1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FINAL="$FFB/scripts.d/zz-final.sh"

grep -q '^ffbuild_depends() {' "$FINAL" || { echo "::error::ffbuild_depends non trovato in $FINAL"; exit 1; }

for s in "$HERE"/scripts.d/??-*.sh; do
    cp -v "$s" "$FFB/scripts.d/"
    name="$(basename "$s" .sh)"; name="${name#??-}"
    if ! grep -qx "    echo $name" "$FINAL"; then
        sed -i "/^ffbuild_depends() {/a\\    echo $name" "$FINAL"
        echo "registrato in zz-final: $name"
    fi
done
