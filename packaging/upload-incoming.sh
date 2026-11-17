#!/usr/bin/env bash
# Carica i pacchetti in incoming/ di packages.fblab.it via SFTP.
# Ogni file viene scritto come <nome>.part e rinominato a trasferimento finito,
# così il publisher non prende mai upload parziali.
#
# Uso: upload-incoming.sh <dir>
#   <dir>/deb/<suite>/<component>/*.deb
#   <dir>/windows/<pacchetto>/*
#
# Variabili: SFTP_HOST SFTP_PORT(22) SFTP_USER SFTP_PASSWORD SFTP_KNOWN_HOSTS REMOTE_DIR
set -euo pipefail

SRC="$(realpath "$1")"
: "${SFTP_HOST:?}" "${SFTP_USER:?}" "${SFTP_PASSWORD:?}" "${SFTP_KNOWN_HOSTS:?}" "${REMOTE_DIR:?}"
SFTP_PORT="${SFTP_PORT:-22}"
R="${REMOTE_DIR%/}/incoming"

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
printf '%s\n' "$SFTP_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/known_hosts"
export LFTP_PASSWORD="$SFTP_PASSWORD"

cmds=""
while IFS= read -r f; do
    rel="${f#./}"
    dir="$(dirname "$rel")"
    # rm -f prima di mv: il rename SFTP (v3) fallisce se la destinazione esiste già
    # (stesso nome già in incoming/, es. due run lo stesso giorno sullo stesso commit)
    cmds+=" mkdir -p -f '$R/$dir'; put '$SRC/$rel' -o '$R/$rel.part'; rm -f '$R/$rel'; mv '$R/$rel.part' '$R/$rel';"
    echo "upload incoming/$rel"
done < <(cd "$SRC" && find . -type f | sort)

[[ -n "$cmds" ]] || { echo "Niente da caricare in $SRC"; exit 1; }

lftp -c "set cmd:fail-exit yes; set net:max-retries 3; set net:reconnect-interval-base 10;
set sftp:connect-program 'ssh -a -x -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts';
open --env-password -u '$SFTP_USER' sftp://$SFTP_HOST:$SFTP_PORT;
$cmds"
echo "Upload completato."
