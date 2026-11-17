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

# Patch dei sorgenti ffmpeg (packaging/ffpatch, es. NDI): build.sh clona ffmpeg
# dentro il container in /ffbuild/ffmpeg; copiamo ffpatch/ in ffbuild/ (montata
# come /ffbuild) e lo applichiamo subito dopo il clone, prima di ./configure.
BUILD="$FFB/build.sh"
rm -rf "$FFB/ffpatch"
cp -r "$HERE/packaging/ffpatch" "$FFB/ffpatch"

hook() {   # hook <regex-ancora> <riga-da-inserire>
    local anchor="$1" line="$2" n
    grep -qxF -- "$line" "$BUILD" && return 0
    n="$(grep -cE -- "$anchor" "$BUILD" || true)"
    [[ "$n" == 1 ]] || { echo "::error::build.sh: ancora '$anchor' trovata $n volte (attesa 1)"; exit 1; }
    ANCHOR="$anchor" LINE="$line" awk '{ print } $0 ~ ENVIRON["ANCHOR"] { print ENVIRON["LINE"] }' "$BUILD" > "$BUILD.tmp"
    cat "$BUILD.tmp" > "$BUILD" && rm -f "$BUILD.tmp"   # cat: conserva il bit di esecuzione
    echo "build.sh: inserito '$line'"
}
hook '^mkdir ffbuild$'   'cp -r ffpatch ffbuild/ffpatch'
hook '^    cd ffmpeg$'   '    bash /ffbuild/ffpatch/apply.sh'
