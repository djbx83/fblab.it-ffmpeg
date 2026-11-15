#!/usr/bin/env bash
# Publisher generico per packages.fblab.it
#
# Uso: publish.sh [staging_dir]
#
# Sorgenti dei nuovi pacchetti (stesso layout per entrambe):
#   <staging_dir>/<archive>/deb/<suite>/*.deb      (artifact della CI corrente)
#   <staging_dir>/<archive>/win64/<subdir>/*
#   REMOTE_DIR/incoming/<archive>/deb/<suite>/*.deb (caricati via SFTP da chiunque)
#   REMOTE_DIR/incoming/<archive>/win64/<subdir>/*
#
# Layout remoto prodotto:
#   REMOTE_DIR/fblab-archive-keyring.gpg (.asc)  chiave pubblica comune a tutti gli archivi
#   REMOTE_DIR/fblab-<archive>-<suite>.sources   file sorgente apt pronti (deb822), uno per suite
#   REMOTE_DIR/<archive>/deb/{dists,pool}/…
#   REMOTE_DIR/<archive>/win64/<subdir>/…
#
# Variabili: quelle di repo/lib.sh e repo/build-dists.sh, più
#   ARCHIVES        default "free non-redistributable"
#   KEEP            versioni per (suite,pacchetto,arch) da tenere, default 3
#   WIN_KEEP        file datati da tenere nelle subdir win64 in WIN_PRUNE_DIRS, default 7
#   WIN_PRUNE_DIRS  default "ffmpeg"
#   INCOMING_MIN_AGE  età minima dei file in incoming (upload completati), default 2 minuti
#   PUBLIC_URL      URL pubblico della root, default https://packages.fblab.it
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo/lib.sh
source "$HERE/lib.sh"

STAGING="$(realpath -m "${1:-staging}")"
ARCHIVES="${ARCHIVES:-free non-redistributable}"
KEEP="${KEEP:-3}"
WIN_KEEP="${WIN_KEEP:-7}"
WIN_PRUNE_DIRS="${WIN_PRUNE_DIRS:-ffmpeg}"
INCOMING_MIN_AGE="${INCOMING_MIN_AGE:-2minutes}"
KEYRING_NAME="${KEYRING_NAME:-fblab-archive-keyring.gpg}"
PUBLIC_URL="${PUBLIC_URL:-https://packages.fblab.it}"

: "${GPG_KEY_ID:?GPG_KEY_ID non impostata}"
sftp_setup
R="$REMOTE_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
NEW="$WORK/new"
mkdir -p "$NEW"

# Chiave pubblica comune nella root: aggiornata a ogni run
gpg --batch --yes --export "$GPG_KEY_ID" > "$WORK/$KEYRING_NAME"
gpg --batch --yes --armor --export "$GPG_KEY_ID" > "$WORK/${KEYRING_NAME%.gpg}.asc"
[[ -s "$WORK/$KEYRING_NAME" ]] || { echo "::error::chiave $GPG_KEY_ID non presente nel keyring"; exit 1; }
lf "put -O $R $WORK/$KEYRING_NAME; put -O $R $WORK/${KEYRING_NAME%.gpg}.asc"
echo "Chiave pubblica aggiornata: $R/$KEYRING_NAME"

# File .sources pronti nella root: uno per (archivio, suite) esistente sul server.
# Rimuove quelli di suite che non esistono più.
update_sources() {
    local sd="$WORK/sources" a s cmds="" f
    rm -rf "$sd"; mkdir -p "$sd"
    for a in $ARCHIVES; do
        while IFS= read -r s; do
            [[ -n "$s" ]] || continue
            cat > "$sd/fblab-$a-$s.sources" <<EOS
Types: deb
URIs: $PUBLIC_URL/$a/deb
Suites: $s
Components: main
Signed-By: /usr/share/keyrings/$KEYRING_NAME
EOS
        done < <(lf_try "cls -1 $R/$a/deb/dists/" | sed -n 's|.*/\([^/][^/]*\)/$|\1|p')
    done
    for f in "$sd"/*.sources; do
        [[ -e "$f" ]] && cmds+=" put -O $R $f;"
    done
    while IFS= read -r f; do
        f="${f##*/}"
        [[ -n "$f" && ! -e "$sd/$f" ]] && cmds+=" rm $R/$f;" && echo "rimosso $f"
    done < <(lf_try "cls -1 $R/fblab-*.sources")
    [[ -n "$cmds" ]] && lf "$cmds"
    (cd "$sd" && ls -1 ./*.sources 2>/dev/null | sed 's|^\./|sources: |') || true
}
update_sources

# ---------------------------------------------------------------------------
# 1. Raccolta: staging locale + incoming remoto (solo file "fermi" da N minuti)
# ---------------------------------------------------------------------------
[[ -d "$STAGING" ]] && cp -a "$STAGING"/. "$NEW"/ 2>/dev/null || true

for a in $ARCHIVES; do
    mkdir -p "$WORK/incoming/$a" "$NEW/$a"
    lf "mkdir -p -f $R/incoming/$a;
        mirror --no-perms --older-than=now-$INCOMING_MIN_AGE $R/incoming/$a $WORK/incoming/$a"
    cp -a "$WORK/incoming/$a"/. "$NEW/$a"/
done

if [[ -z "$(find "$NEW" -type f -print -quit)" ]]; then
    echo "Niente da pubblicare."
    exit 0
fi
echo "== Nuovi file =="
(cd "$NEW" && find . -type f | sort)

# ---------------------------------------------------------------------------
# 2. Archivi APT
# ---------------------------------------------------------------------------
pool_prefix() { if [[ "$1" == lib?* ]]; then echo "${1:0:4}"; else echo "${1:0:1}"; fi; }

for a in $ARCHIVES; do
    shopt -s nullglob
    newdebs=( "$NEW/$a"/deb/*/*.deb )
    shopt -u nullglob
    (( ${#newdebs[@]} )) || continue

    echo "== Archivio $a =="
    A="$WORK/repo/$a"
    mkdir -p "$A/pool"
    lf "mkdir -p -f $R/$a/deb/pool; mirror --no-perms --parallel=4 $R/$a/deb/pool $A/pool"

    for deb in "${newdebs[@]}"; do
        suite="$(basename "$(dirname "$deb")")"
        if ! pkg="$(dpkg-deb -f "$deb" Package 2>/dev/null)"; then
            echo "::warning::scartato (non è un .deb valido): $a/deb/$suite/$(basename "$deb")"
            continue
        fi
        dest="$A/pool/$suite/main/$(pool_prefix "$pkg")/$pkg"
        mkdir -p "$dest"
        cp -f "$deb" "$dest/"
        echo "+ $suite/$pkg $(dpkg-deb -f "$deb" Version) $(dpkg-deb -f "$deb" Architecture)"
    done

    python3 "$HERE/prune.py" "$A/pool" "$KEEP"
    bash "$HERE/build-dists.sh" "$A" "$a"

    # Ordine: nuovi .deb -> Packages -> Release/InRelease -> cancellazioni
    cmds="mirror -R --no-perms --parallel=2 $A/pool $R/$a/deb/pool;
          mirror -R --no-perms --exclude-glob Release --exclude-glob Release.gpg --exclude-glob InRelease $A/dists $R/$a/deb/dists;"
    for sd in "$A"/dists/*/; do
        s="$(basename "$sd")"
        cmds+=" put -O $R/$a/deb/dists/$s $A/dists/$s/Release;"
        cmds+=" put -O $R/$a/deb/dists/$s $A/dists/$s/Release.gpg;"
        cmds+=" put -O $R/$a/deb/dists/$s $A/dists/$s/InRelease;"
    done
    # chiave per-archivio delle versioni precedenti: ora è comune nella root
    cmds+=" rm -f $R/$a/deb/$KEYRING_NAME;
            mirror -R --no-perms --delete $A/pool $R/$a/deb/pool;
            mirror -R --no-perms --delete $A/dists $R/$a/deb/dists;"
    lf "$cmds"
done

# ---------------------------------------------------------------------------
# 3. Pacchetti Windows
# ---------------------------------------------------------------------------
for a in $ARCHIVES; do
    [[ -d "$NEW/$a/win64" ]] || continue
    for sd in "$NEW/$a"/win64/*/; do
        [[ -d "$sd" ]] || continue
        sub="$(basename "$sd")"
        W="$R/$a/win64/$sub"
        echo "== $a/win64/$sub =="
        lf "mkdir -p -f $W; mirror -R --no-perms $sd $W"

        if [[ " $WIN_PRUNE_DIRS " == *" $sub "* ]]; then
            mapfile -t remote < <(lf_try "cls -1 --sort=name $W/" | sed 's|.*/||' | grep -v -- '-latest-' | grep -v '^$' || true)
            if (( ${#remote[@]} > WIN_KEEP )); then
                del=""
                for f in "${remote[@]:0:${#remote[@]}-WIN_KEEP}"; do del+=" rm $W/$f;"; echo "prune win64/$sub/$f"; done
                lf "$del"
            fi
        fi
    done
done

# ---------------------------------------------------------------------------
# 4. Pulizia incoming: solo i file effettivamente processati
# ---------------------------------------------------------------------------
for a in $ARCHIVES; do
    del=""
    while IFS= read -r f; do
        del+=" rm '$R/incoming/$a/${f#./}';"
    done < <(cd "$WORK/incoming/$a" && find . -type f)
    [[ -n "$del" ]] && lf "$del"
done

update_sources
echo "Pubblicazione completata."
