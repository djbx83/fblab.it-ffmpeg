#!/usr/bin/env bash
# Pubblica repo APT e zip Windows sullo spazio web via SFTP (lftp).
#
# Uso: upload.sh <repo_dir> <win_dir>
#
# Variabili (da GitHub Secrets/Variables):
#   SFTP_HOST         es. ftp.clusterXXX.hosting.ovh.net
#   SFTP_PORT         default 22
#   SFTP_USER
#   SFTP_PASSWORD
#   SFTP_KNOWN_HOSTS  riga/e known_hosts dell'host (host key pinning)
#   REMOTE_DIR        directory remota base, es. www/ffmpeg
#   WIN_KEEP          numero di zip Windows da conservare (default 7)
#
# Ordine di pubblicazione pensato per non esporre mai un indice
# che punta a file non ancora presenti:
#   1. pool (nuovi .deb)  2. Packages*  3. Release/Release.gpg/InRelease
#   4. pulizia vecchi .deb dal pool  5. zip Windows + retention
set -euo pipefail

REPO="$1"
WIN="$2"

: "${SFTP_HOST:?}" "${SFTP_USER:?}" "${SFTP_PASSWORD:?}" "${SFTP_KNOWN_HOSTS:?}" "${REMOTE_DIR:?}"
SFTP_PORT="${SFTP_PORT:-22}"
WIN_KEEP="${WIN_KEEP:-7}"
SUITE="${SUITE:-ffmpeg}"

mkdir -p ~/.ssh && chmod 700 ~/.ssh
printf '%s\n' "$SFTP_KNOWN_HOSTS" > ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts

export LFTP_PASSWORD="$SFTP_PASSWORD"

LFTP_PRE="set cmd:fail-exit yes; set net:max-retries 3; set net:reconnect-interval-base 10;
set sftp:connect-program 'ssh -a -x -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts';
open --env-password -u '$SFTP_USER' sftp://$SFTP_HOST:$SFTP_PORT;"

R="$REMOTE_DIR/apt"

# 1. nuovi .deb (senza cancellare i vecchi: i client con indice vecchio li trovano ancora)
# 2. indici Packages
# 3. Release / Release.gpg / InRelease per ultimi
# 4. pulizia pool
lftp -c "$LFTP_PRE
mkdir -p -f $R/pool $R/dists/$SUITE;
mirror -R --no-perms --parallel=2 $REPO/pool $R/pool;
mirror -R --no-perms --exclude-glob Release --exclude-glob Release.gpg --exclude-glob InRelease $REPO/dists/$SUITE $R/dists/$SUITE;
put -O $R/dists/$SUITE $REPO/dists/$SUITE/Release;
put -O $R/dists/$SUITE $REPO/dists/$SUITE/Release.gpg;
put -O $R/dists/$SUITE $REPO/dists/$SUITE/InRelease;
put -O $R $REPO/ffmpeg-nightly-archive-keyring.gpg;
mirror -R --no-perms --delete $REPO/pool $R/pool;
"

# 5. zip Windows: file datato + copia "latest" (niente symlink via SFTP su hosting condiviso)
shopt -s nullglob
zips=( "$WIN"/*.zip )
if (( ${#zips[@]} )); then
    W="$REMOTE_DIR/win"
    cmds="mkdir -p -f $W;"
    for z in "${zips[@]}"; do
        cmds+=" put -O $W $z;"
    done
    cmds+=" put ${zips[-1]} -o $W/ffmpeg-latest-win64-nonfree.zip;"
    lftp -c "$LFTP_PRE $cmds"

    # retention: tiene gli ultimi WIN_KEEP zip datati
    mapfile -t remote < <(lftp -c "$LFTP_PRE cls -1 --sort=name $W/ffmpeg-2*-win64-nonfree.zip" 2>/dev/null || true)
    if (( ${#remote[@]} > WIN_KEEP )); then
        del=""
        for f in "${remote[@]:0:${#remote[@]}-WIN_KEEP}"; do del+=" rm $f;"; done
        lftp -c "$LFTP_PRE $del"
    fi
fi

echo "Upload completato."
